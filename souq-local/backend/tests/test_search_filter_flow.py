"""End-to-end /search filter flow regression tests for products and services."""

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
    assert categories.status_code == 200, categories.text
    return next(item["id"] for item in categories.json() if item["slug"] == slug)


async def _register_seller(client: AsyncClient) -> dict:
    tokens = await register_test_user(
        client,
        email=f"seller-{uuid4().hex[:8]}@example.com",
        account_type="provider",
        display_name="Seller",
    )
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _create_listing_set(client: AsyncClient) -> dict:
    near = await _register_seller(client)
    far = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    food_id = await _category_id(client, "food")

    near_profile = await create_test_seller(
        client,
        near["headers"],
        **seller_create_payload(
            business_name="Near Electronics",
            category_ids=[electronics_id],
            marketplace_slug="derb-ghallef",
            latitude=ORIGIN_LAT + 0.01,
            longitude=ORIGIN_LNG + 0.01,
        ),
    )
    far_profile = await create_test_seller(
        client,
        far["headers"],
        **seller_create_payload(
            business_name="Far Food Shop",
            category_ids=[food_id],
            latitude=ORIGIN_LAT + 0.2,
            longitude=ORIGIN_LNG + 0.2,
        ),
    )

    near_product = await client.post(
        f"/sellers/{near_profile['id']}/products",
        headers=near["headers"],
        json={
            "name": "Near Phone",
            "description": "Smartphone",
            "price_mad": 1200,
            "category_slug": "electronics",
            "delivery_available": True,
        },
    )
    far_product = await client.post(
        f"/sellers/{far_profile['id']}/products",
        headers=far["headers"],
        json={"name": "Far Snack", "price_mad": 20, "category_slug": "food"},
    )
    near_service = await client.post(
        f"/sellers/{near_profile['id']}/services",
        headers=near["headers"],
        json={"name": "Near Repair", "description": "Phone repair", "price_mad": 150, "category_slug": "electronics"},
    )
    far_service = await client.post(
        f"/sellers/{far_profile['id']}/services",
        headers=far["headers"],
        json={"name": "Far Catering", "description": "Buffet", "price_mad": 400, "category_slug": "food"},
    )
    assert near_product.status_code == 201, near_product.text
    assert far_product.status_code == 201, far_product.text
    assert near_service.status_code == 201, near_service.text
    assert far_service.status_code == 201, far_service.text

    return {
        "near_product_id": near_product.json()["id"],
        "far_product_id": far_product.json()["id"],
        "near_service_id": near_service.json()["id"],
        "far_service_id": far_service.json()["id"],
    }


@pytest.mark.asyncio
async def test_product_category_marketplace_city_search_sort_filters(client: AsyncClient):
    await _seed_catalog_data()
    listings = await _create_listing_set(client)

    # 1 Product → Category
    by_category = await client.get(
        "/search",
        params={"mode": "products", "category": "phones", "marketplace": "derb-ghallef"},
    )
    assert by_category.status_code == 200, by_category.text
    product_ids = {item["id"] for item in by_category.json()["products"]}
    assert listings["near_product_id"] in product_ids
    assert listings["far_product_id"] not in product_ids

    # 2 Product → City
    by_city = await client.get("/search", params={"mode": "products", "city": "Casablanca"})
    assert by_city.status_code == 200
    assert listings["near_product_id"] in {item["id"] for item in by_city.json()["products"]}

    # 3 Product → Search
    by_search = await client.get("/search", params={"mode": "products", "q": "Near Phone"})
    assert by_search.status_code == 200
    assert listings["near_product_id"] in {item["id"] for item in by_search.json()["products"]}

    # 4 Product → Nearest
    by_nearest = await client.get(
        "/search",
        params={
            "mode": "products",
            "sort": "distance",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
            "limit": 10,
        },
    )
    assert by_nearest.status_code == 200, by_nearest.text
    nearest_ids = [item["id"] for item in by_nearest.json()["products"]]
    assert nearest_ids.index(listings["near_product_id"]) < nearest_ids.index(listings["far_product_id"])

    # 5 Product → Relevance
    by_relevance = await client.get("/search", params={"mode": "products", "sort": "relevance", "q": "Phone"})
    assert by_relevance.status_code == 200
    assert listings["near_product_id"] in {item["id"] for item in by_relevance.json()["products"]}

    # 6 Product → Filter A → Filter B
    combined = await client.get(
        "/search",
        params={
            "mode": "products",
            "category": "electronics",
            "min_price": 1000,
            "max_price": 1500,
            "delivery_available": True,
        },
    )
    assert combined.status_code == 200
    combined_ids = {item["id"] for item in combined.json()["products"]}
    assert listings["near_product_id"] in combined_ids
    assert listings["far_product_id"] not in combined_ids

    # 7 Product → Clear → all results
    cleared = await client.get("/search", params={"mode": "products", "limit": 50})
    assert cleared.status_code == 200
    all_ids = {item["id"] for item in cleared.json()["products"]}
    assert listings["near_product_id"] in all_ids
    assert listings["far_product_id"] in all_ids


@pytest.mark.asyncio
async def test_service_category_city_search_sort_filters(client: AsyncClient):
    await _seed_catalog_data()
    listings = await _create_listing_set(client)

    # 8 Service → Category
    by_category = await client.get("/search", params={"mode": "services", "category": "food"})
    assert by_category.status_code == 200
    service_ids = {item["id"] for item in by_category.json()["services"]}
    assert listings["far_service_id"] in service_ids
    assert listings["near_service_id"] not in service_ids

    # 9 Service → City
    by_city = await client.get("/search", params={"mode": "services", "city": "casablanca"})
    assert by_city.status_code == 200
    assert listings["near_service_id"] in {item["id"] for item in by_city.json()["services"]}

    # 10 Service → Search
    by_search = await client.get("/search", params={"mode": "services", "q": "Repair"})
    assert by_search.status_code == 200
    assert listings["near_service_id"] in {item["id"] for item in by_search.json()["services"]}

    # 11 Service → Nearest
    by_nearest = await client.get(
        "/search",
        params={
            "mode": "services",
            "sort": "distance",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
            "limit": 10,
        },
    )
    assert by_nearest.status_code == 200, by_nearest.text
    nearest_ids = [item["id"] for item in by_nearest.json()["services"]]
    assert nearest_ids.index(listings["near_service_id"]) < nearest_ids.index(listings["far_service_id"])

    # 12 Service → Relevance
    by_relevance = await client.get("/search", params={"mode": "services", "sort": "relevance", "q": "Catering"})
    assert by_relevance.status_code == 200
    assert listings["far_service_id"] in {item["id"] for item in by_relevance.json()["services"]}

    # 13 Service → Filter A → Filter B
    combined = await client.get(
        "/search",
        params={"mode": "services", "category": "electronics", "min_rating": 0, "q": "Repair"},
    )
    assert combined.status_code == 200
    assert listings["near_service_id"] in {item["id"] for item in combined.json()["services"]}

    # 14 Service → Clear → all results
    cleared = await client.get("/search", params={"mode": "services", "limit": 50})
    assert cleared.status_code == 200
    all_ids = {item["id"] for item in cleared.json()["services"]}
    assert listings["near_service_id"] in all_ids
    assert listings["far_service_id"] in all_ids


@pytest.mark.asyncio
async def test_sort_toggle_and_pagination_refresh(client: AsyncClient):
    await _seed_catalog_data()
    seller = await _register_seller(client)
    electronics_id = await _category_id(client, "electronics")
    profile = await create_test_seller(
        client,
        seller["headers"],
        **seller_create_payload(
            category_ids=[electronics_id],
            latitude=ORIGIN_LAT + 0.01,
            longitude=ORIGIN_LNG + 0.01,
        ),
    )
    created = []
    for index in range(3):
        response = await client.post(
            f"/sellers/{profile['id']}/products",
            headers=seller["headers"],
            json={
                "name": f"Paged Product {index}",
                "price_mad": 100 + index,
                "category_slug": "electronics",
            },
        )
        assert response.status_code == 201, response.text
        created.append(response.json()["id"])

    # 17 Relevance → Nearest → Relevance
    relevance = await client.get(
        "/search",
        params={"mode": "products", "sort": "relevance", "category": "electronics", "q": "Paged"},
    )
    assert relevance.status_code == 200
    assert relevance.json()["total_products"] == 3

    nearest = await client.get(
        "/search",
        params={
            "mode": "products",
            "sort": "distance",
            "category": "electronics",
            "q": "Paged",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
        },
    )
    assert nearest.status_code == 200
    assert len(nearest.json()["products"]) == 3

    relevance_again = await client.get(
        "/search",
        params={"mode": "products", "sort": "relevance", "category": "electronics", "q": "Paged"},
    )
    assert relevance_again.status_code == 200
    assert relevance_again.json()["total_products"] == 3

    # 19 Filter → pagination
    page_one = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "q": "Paged", "limit": 2, "offset": 0},
    )
    page_two = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "q": "Paged", "limit": 2, "offset": 2},
    )
    assert page_one.json()["has_more"] is True
    assert page_two.json()["has_more"] is False
    returned = {item["id"] for item in page_one.json()["products"] + page_two.json()["products"]}
    assert returned == set(created)

    # 20 Filter → refresh (same params should return same totals)
    refresh = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "q": "Paged"},
    )
    assert refresh.json()["total_products"] == 3
