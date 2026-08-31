"""End-to-end regression tests for the marketplace search filter system."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.data.marketplace_categories import MARKETPLACE_CATEGORIES
from app.main import app
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")

ORIGIN_LAT, ORIGIN_LNG = 33.5731, -7.5898


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
        if (await session.execute(select(Category.id).limit(1))).scalar_one_or_none() is None:
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
        if (
            await session.execute(select(Marketplace).where(Marketplace.slug == "derb-ghallef"))
        ).scalar_one_or_none() is None:
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


async def _category_id(client: AsyncClient, slug: str) -> str:
    categories = await client.get("/categories")
    return next(item["id"] for item in categories.json() if item["slug"] == slug)


async def _register_seller(client: AsyncClient) -> dict:
    tokens = await register_test_user(
        client,
        email=f"seller-{uuid4().hex[:8]}@example.com",
        account_type="provider",
        display_name="Seller",
    )
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


@pytest.mark.asyncio
async def test_service_relevance_sort_ranks_name_prefix_first(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )
    alpha = await client.post(
        f"/sellers/{profile['id']}/services",
        headers=seller["headers"],
        json={"name": "Alpha Repair", "description": "General", "price_mad": 100},
    )
    zebra = await client.post(
        f"/sellers/{profile['id']}/services",
        headers=seller["headers"],
        json={"name": "Zebra Repair", "description": "General", "price_mad": 100},
    )
    assert alpha.status_code == 201 and zebra.status_code == 201

    response = await client.get(
        "/search",
        params={"mode": "services", "sort": "relevance", "q": "Alpha"},
    )
    assert response.status_code == 200, response.text
    ids = [item["id"] for item in response.json()["services"]]
    assert ids.index(alpha.json()["id"]) == 0
    assert zebra.json()["id"] not in ids


@pytest.mark.asyncio
async def test_uncategorized_multi_category_seller_does_not_leak(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    food_id = await _category_id(client, "food")
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            business_name="Mixed Booth",
            category_ids=[electronics_id, food_id],
        ),
    )
    uncategorized = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Mystery Item", "price_mad": 30},
    )
    assert uncategorized.status_code == 201, uncategorized.text
    product_id = uncategorized.json()["id"]

    electronics = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics"},
    )
    food = await client.get(
        "/search",
        params={"mode": "products", "category": "food"},
    )
    assert product_id not in {item["id"] for item in electronics.json()["products"]}
    assert product_id not in {item["id"] for item in food.json()["products"]}


@pytest.mark.asyncio
async def test_uncategorized_single_category_seller_still_matches(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )
    uncategorized = await client.post(
        f"/sellers/{profile['id']}/products",
        headers=seller["headers"],
        json={"name": "Cable", "price_mad": 40},
    )
    assert uncategorized.status_code == 201, uncategorized.text
    product_id = uncategorized.json()["id"]

    filtered = await client.get(
        "/search",
        params={"mode": "products", "category": "phones"},
    )
    assert product_id in {item["id"] for item in filtered.json()["products"]}


@pytest.mark.asyncio
async def test_sort_relevance_nearest_toggle_preserves_results(client: AsyncClient):
    await _seed_catalog_data()
    near = await _register_seller(client)
    far = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    near_profile = await create_test_seller(
        client,
        near["headers"],
        **seller_create_payload(
            category_ids=[electronics_id],
            latitude=ORIGIN_LAT + 0.01,
            longitude=ORIGIN_LNG + 0.01,
        ),
    )
    far_profile = await create_test_seller(
        client,
        far["headers"],
        **seller_create_payload(
            category_ids=[electronics_id],
            latitude=ORIGIN_LAT + 0.25,
            longitude=ORIGIN_LNG + 0.25,
        ),
    )
    near_product = await client.post(
        f"/sellers/{near_profile['id']}/products",
        headers=near["headers"],
        json={"name": "Near Widget", "price_mad": 50, "category_slug": "electronics"},
    )
    far_product = await client.post(
        f"/sellers/{far_profile['id']}/products",
        headers=far["headers"],
        json={"name": "Far Widget", "price_mad": 50, "category_slug": "electronics"},
    )
    assert near_product.status_code == 201 and far_product.status_code == 201
    near_id = near_product.json()["id"]
    far_id = far_product.json()["id"]

    relevance = await client.get(
        "/search",
        params={"mode": "products", "sort": "relevance", "category": "electronics"},
    )
    nearest = await client.get(
        "/search",
        params={
            "mode": "products",
            "sort": "distance",
            "category": "electronics",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
        },
    )
    relevance_again = await client.get(
        "/search",
        params={"mode": "products", "sort": "relevance", "category": "electronics"},
    )
    nearest_again = await client.get(
        "/search",
        params={
            "mode": "products",
            "sort": "distance",
            "category": "electronics",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
        },
    )

    for response in (relevance, relevance_again):
        ids = {item["id"] for item in response.json()["products"]}
        assert near_id in ids and far_id in ids

    for response in (nearest, nearest_again):
        ids = [item["id"] for item in response.json()["products"]]
        assert near_id in ids and far_id in ids
        assert ids.index(near_id) < ids.index(far_id)


@pytest.mark.asyncio
async def test_search_category_price_city_combined_filters(client: AsyncClient):
    await _seed_catalog_data()
    casablanca = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    casa_profile = await create_test_seller(
        client,
        casablanca["headers"],
        **seller_create_payload(
            business_name="Casa Shop",
            category_ids=[electronics_id],
            city="Casablanca",
        ),
    )
    match = await client.post(
        f"/sellers/{casa_profile['id']}/products",
        headers=casablanca["headers"],
        json={"name": "Casa Phone", "price_mad": 1200, "category_slug": "electronics"},
    )
    wrong_price = await client.post(
        f"/sellers/{casa_profile['id']}/products",
        headers=casablanca["headers"],
        json={"name": "Casa Cheap", "price_mad": 50, "category_slug": "electronics"},
    )
    assert all(r.status_code == 201 for r in (match, wrong_price))

    response = await client.get(
        "/search",
        params={
            "mode": "products",
            "q": "Phone",
            "category": "electronics",
            "city": "Casablanca",
            "min_price": 1000,
            "max_price": 1500,
        },
    )
    ids = {item["id"] for item in response.json()["products"]}
    assert match.json()["id"] in ids
    assert wrong_price.json()["id"] not in ids

    wrong_city = await client.get(
        "/search",
        params={
            "mode": "products",
            "q": "Phone",
            "category": "electronics",
            "city": "Rabat",
            "min_price": 1000,
            "max_price": 1500,
        },
    )
    assert match.json()["id"] not in {item["id"] for item in wrong_city.json()["products"]}


@pytest.mark.asyncio
async def test_products_and_services_filters_are_independent(client: AsyncClient):
    await _seed_catalog_data()
    product_seller = await _register_seller(client)
    service_seller = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    food_id = await _category_id(client, "food")
    product_profile = await create_test_seller(
        client,
        product_seller["headers"],
        **seller_create_payload(category_ids=[electronics_id]),
    )
    service_profile = await create_test_seller(
        client,
        service_seller["headers"],
        **seller_create_payload(category_ids=[food_id]),
    )
    product = await client.post(
        f"/sellers/{product_profile['id']}/products",
        headers=product_seller["headers"],
        json={"name": "Gadget", "price_mad": 500, "category_slug": "electronics"},
    )
    service = await client.post(
        f"/sellers/{service_profile['id']}/services",
        headers=service_seller["headers"],
        json={"name": "Catering", "price_mad": 50, "category_slug": "food"},
    )
    assert product.status_code == 201 and service.status_code == 201

    products = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "min_price": 400},
    )
    services = await client.get(
        "/search",
        params={"mode": "services", "category": "food", "max_price": 100},
    )
    assert product.json()["id"] in {item["id"] for item in products.json()["products"]}
    assert service.json()["id"] in {item["id"] for item in services.json()["services"]}
    assert service.json()["id"] not in {item["id"] for item in products.json()["products"]}
    assert product.json()["id"] not in {item["id"] for item in services.json()["services"]}
