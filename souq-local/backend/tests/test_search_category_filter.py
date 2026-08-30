"""Search category filter resolution and listing visibility."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.data.marketplace_categories import MARKETPLACE_CATEGORIES
from app.main import app
from app.services.search_categories import resolve_listing_category_slugs
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _seed_catalog_data() -> None:
    import app.database as database
    from sqlalchemy import select

    from app.models import Category
    from app.models.marketplace import Marketplace

    async with database.SessionLocal() as session:
        existing = (await session.execute(select(Category.id).limit(1))).scalar_one_or_none()
        if existing is None:
            for cat in MARKETPLACE_CATEGORIES:
                session.add(
                    Category(
                        slug=cat.slug,
                        name_en=cat.name_en,
                        name_fr=cat.name_fr,
                        name_ar=cat.name_ar,
                        icon=cat.icon,
                    )
                )

        marketplace = (
            await session.execute(select(Marketplace).where(Marketplace.slug == "derb-ghallef"))
        ).scalar_one_or_none()
        if marketplace is None:
            session.add(
                Marketplace(
                    id=uuid4(),
                    slug="derb-ghallef",
                    name="Derb Ghallef",
                    description="Electronics market",
                    address="Derb Ghallef",
                    district="Derb Ghallef",
                    city="Casablanca",
                    latitude=33.5789,
                    longitude=-7.61,
                    display_order=1,
                    is_active=True,
                )
            )

        await session.commit()


async def _register_seller(client: AsyncClient) -> dict:
    email = f"seller-{uuid4().hex[:8]}@example.com"
    tokens = await register_test_user(
        client,
        email=email,
        account_type="provider",
        display_name="Seller",
    )
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _electronics_category_id(client: AsyncClient) -> str:
    categories = await client.get("/categories")
    assert categories.status_code == 200, categories.text
    match = next(item for item in categories.json() if item["slug"] == "electronics")
    return match["id"]


async def _food_category_id(client: AsyncClient) -> str:
    categories = await client.get("/categories")
    assert categories.status_code == 200, categories.text
    match = next(item for item in categories.json() if item["slug"] == "food")
    return match["id"]


def test_resolve_marketplace_category_to_fundamental_slug():
    assert resolve_listing_category_slugs("phones") == frozenset({"electronics"})
    assert resolve_listing_category_slugs("Electronics") == frozenset({"electronics"})
    assert resolve_listing_category_slugs("services") == frozenset({"home"})
    assert resolve_listing_category_slugs(None) is None
    assert resolve_listing_category_slugs("") is None


@pytest.mark.asyncio
async def test_search_products_by_marketplace_category_slug(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            business_name="Phone Shop",
            category_ids=[electronics_id],
            marketplace_slug="derb-ghallef",
        ),
    )
    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Samsung Galaxy",
            "description": "Smartphone",
            "price_mad": 2500,
            "category_slug": "electronics",
        },
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    filtered = await client.get(
        "/search",
        params={
            "mode": "products",
            "category": "phones",
            "marketplace": "derb-ghallef",
            "limit": 20,
        },
    )
    assert filtered.status_code == 200, filtered.text
    body = filtered.json()
    assert body["total_products"] == 1
    assert body["products"][0]["id"] == product_id


@pytest.mark.asyncio
async def test_search_products_without_listing_category_use_seller_category(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            business_name="Repair Booth",
            category_ids=[electronics_id],
            marketplace_slug="derb-ghallef",
        ),
    )
    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Charger Cable",
            "description": "USB-C cable",
            "price_mad": 80,
        },
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    filtered = await client.get(
        "/search",
        params={"mode": "products", "category": "gaming", "limit": 20},
    )
    assert filtered.status_code == 200, filtered.text
    ids = {item["id"] for item in filtered.json()["products"]}
    assert product_id in ids


@pytest.mark.asyncio
async def test_search_services_by_fundamental_category(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    food_id = await _food_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            business_name="Catering Co",
            category_ids=[food_id],
        ),
    )
    service = await client.post(
        f"/sellers/{profile['id']}/services",
        headers=seller["headers"],
        json={
            "name": "Event Catering",
            "description": "Buffet service",
            "price_mad": 500,
            "category_slug": "food",
        },
    )
    assert service.status_code == 201, service.text
    service_id = service.json()["id"]

    filtered = await client.get(
        "/search",
        params={"mode": "services", "category": "food", "limit": 20},
    )
    assert filtered.status_code == 200, filtered.text
    body = filtered.json()
    assert body["total_services"] == 1
    assert body["services"][0]["id"] == service_id


@pytest.mark.asyncio
async def test_search_multiple_categories_only_return_matching_listings(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    food_id = await _food_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            business_name="Mixed Shop",
            category_ids=[electronics_id, food_id],
        ),
    )
    phone = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Phone Case",
            "price_mad": 50,
            "category_slug": "electronics",
        },
    )
    snack = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Dates Box",
            "price_mad": 40,
            "category_slug": "food",
        },
    )
    assert phone.status_code == 201, phone.text
    assert snack.status_code == 201, snack.text

    electronics_only = await client.get(
        "/search",
        params={"mode": "products", "category": "phones", "limit": 20},
    )
    assert electronics_only.status_code == 200, electronics_only.text
    ids = {item["id"] for item in electronics_only.json()["products"]}
    assert phone.json()["id"] in ids
    assert snack.json()["id"] not in ids


@pytest.mark.asyncio
async def test_search_ignores_unknown_marketplace_slug(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    profile = await create_test_seller(client, seller["headers"])
    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Open Listing", "price_mad": 25},
    )
    assert product.status_code == 201, product.text

    response = await client.get(
        "/search",
        params={"mode": "products", "marketplace": "does-not-exist", "limit": 20},
    )
    assert response.status_code == 200, response.text
    ids = {item["id"] for item in response.json()["products"]}
    assert product.json()["id"] in ids


@pytest.mark.asyncio
async def test_search_without_category_returns_all_active_listings(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    profile = await create_test_seller(client, seller["headers"])
    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Open Listing", "price_mad": 25},
    )
    assert product.status_code == 201, product.text

    unfiltered = await client.get("/search", params={"mode": "products", "limit": 20})
    assert unfiltered.status_code == 200, unfiltered.text
    ids = {item["id"] for item in unfiltered.json()["products"]}
    assert product.json()["id"] in ids


@pytest.mark.asyncio
async def test_search_category_slug_match_is_case_insensitive(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )

    import app.database as database

    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Legacy Case Product", "price_mad": 99, "category_slug": "electronics"},
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    async with database.SessionLocal() as session:
        from app.models import Product

        row = await session.get(Product, product_id)
        row.category_slug = "Electronics"
        await session.commit()

    filtered = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "limit": 20},
    )
    assert filtered.status_code == 200, filtered.text
    ids = {item["id"] for item in filtered.json()["products"]}
    assert product_id in ids


@pytest.mark.asyncio
async def test_products_mode_required_for_home_style_product_category_filter(client: AsyncClient):
    """Document: services mode + electronics category excludes products (the pre-fix UI bug)."""
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )
    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Visible Phone", "price_mad": 100, "category_slug": "electronics"},
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    wrong_mode = await client.get(
        "/search",
        params={"mode": "services", "category": "phones", "limit": 20},
    )
    assert product_id not in {p["id"] for p in wrong_mode.json().get("products", [])}

    correct_mode = await client.get(
        "/search",
        params={"mode": "products", "category": "phones", "limit": 20},
    )
    assert product_id in {p["id"] for p in correct_mode.json()["products"]}


@pytest.mark.asyncio
async def test_search_category_filter_with_query_and_pagination(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _electronics_category_id(client)
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )
    created_ids = []
    for index in range(3):
        response = await client.post(
            f"/sellers/{profile['id']}/products",
            headers=seller["headers"],
            json={
                "name": f"Filterable Gadget {index}",
                "description": "electronics item",
                "price_mad": 100 + index,
                "category_slug": "electronics",
            },
        )
        assert response.status_code == 201, response.text
        created_ids.append(response.json()["id"])

    page_one = await client.get(
        "/search",
        params={
            "mode": "products",
            "category": "electronics",
            "q": "Filterable",
            "limit": 2,
            "offset": 0,
        },
    )
    assert page_one.status_code == 200, page_one.text
    body = page_one.json()
    assert body["total_products"] == 3
    assert len(body["products"]) == 2
    assert body["has_more"] is True

    page_two = await client.get(
        "/search",
        params={
            "mode": "products",
            "category": "electronics",
            "q": "Filterable",
            "limit": 2,
            "offset": 2,
        },
    )
    assert page_two.status_code == 200, page_two.text
    second = page_two.json()
    assert len(second["products"]) == 1
    assert second["has_more"] is False
    returned_ids = {item["id"] for item in body["products"] + second["products"]}
    assert returned_ids == set(created_ids)


@pytest.mark.asyncio
async def test_search_category_matches_uncategorized_product_for_multi_category_seller(
    client: AsyncClient,
):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    categories = await client.get("/categories")
    assert categories.status_code == 200, categories.text
    by_slug = {item["slug"]: item["id"] for item in categories.json()}
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            category_ids=[by_slug["electronics"], by_slug["food"]],
        ),
    )

    product = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Uncategorized Phone", "price_mad": 999},
    )
    assert product.status_code == 201, product.text
    product_id = product.json()["id"]

    filtered = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "limit": 20},
    )
    assert filtered.status_code == 200, filtered.text
    ids = {item["id"] for item in filtered.json()["products"]}
    assert product_id in ids
