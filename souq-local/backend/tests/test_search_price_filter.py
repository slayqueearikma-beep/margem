"""Regression tests for /search min_price and max_price interval filters."""

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


async def _register_seller(client: AsyncClient) -> dict:
    tokens = await register_test_user(
        client,
        email=f"seller-{uuid4().hex[:8]}@example.com",
        account_type="provider",
        display_name="Seller",
    )
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _category_id(client: AsyncClient, slug: str) -> str:
    categories = await client.get("/categories")
    assert categories.status_code == 200, categories.text
    return next(item["id"] for item in categories.json() if item["slug"] == slug)


async def _seed_price_catalog(client: AsyncClient) -> dict:
    await _seed_catalog_data()
    electronics_id = await _category_id(client, "electronics")

    product_seller = await _register_seller(client)
    product_profile = await create_test_seller(
        client,
        product_seller["headers"],
        **seller_create_payload(
            business_name="Price Product Shop",
            category_ids=[electronics_id],
            latitude=ORIGIN_LAT + 0.01,
            longitude=ORIGIN_LNG + 0.01,
        ),
    )

    service_seller = await _register_seller(client)
    service_profile = await create_test_seller(
        client,
        service_seller["headers"],
        **seller_create_payload(
            business_name="Price Service Shop",
            category_ids=[electronics_id],
            latitude=ORIGIN_LAT + 0.01,
            longitude=ORIGIN_LNG + 0.01,
        ),
    )

    async def create_product(name: str, price_mad: float) -> str:
        response = await client.post(
            f"/sellers/{product_profile['id']}/products",
            headers=product_seller["headers"],
            json={
                "name": name,
                "price_mad": price_mad,
                "category_slug": "electronics",
            },
        )
        assert response.status_code == 201, response.text
        return response.json()["id"]

    async def create_service(name: str, **pricing) -> str:
        response = await client.post(
            f"/sellers/{service_profile['id']}/services",
            headers=service_seller["headers"],
            json={"name": name, "description": name, "category_slug": "electronics", **pricing},
        )
        assert response.status_code == 201, response.text
        return response.json()["id"]

    return {
        "product_50": await create_product("Product 50", 50),
        "product_99_5": await create_product("Product 99.5", 99.5),
        "product_100": await create_product("Product 100", 100),
        "product_250": await create_product("Product 250", 250),
        "product_500": await create_product("Product 500", 500),
        "service_80": await create_service("Service 80", pricing_model="hourly", price_mad=80),
        "service_150": await create_service("Service 150", price_mad=150),
        "service_range": await create_service(
            "Service Range",
            pricing_model="price_range",
            price_min_mad=200,
            price_max_mad=400,
        ),
        "service_free": await create_service("Service Free", pricing_model="free"),
        "service_quote": await create_service(
            "Service Quote",
            pricing_model="request_quote",
        ),
    }


def _product_ids(response) -> set[str]:
    return {item["id"] for item in response.json()["products"]}


def _service_ids(response) -> set[str]:
    return {item["id"] for item in response.json()["services"]}


@pytest.mark.asyncio
async def test_product_price_interval_filter_matrix(client: AsyncClient):
    listings = await _seed_price_catalog(client)

    # 1 Min only
    min_only = await client.get("/search", params={"mode": "products", "min_price": 100})
    assert min_only.status_code == 200, min_only.text
    ids = _product_ids(min_only)
    assert listings["product_100"] in ids
    assert listings["product_250"] in ids
    assert listings["product_50"] not in ids
    assert listings["product_99_5"] not in ids

    # 2 Max only
    max_only = await client.get("/search", params={"mode": "products", "max_price": 100})
    assert max_only.status_code == 200
    ids = _product_ids(max_only)
    assert listings["product_50"] in ids
    assert listings["product_99_5"] in ids
    assert listings["product_100"] in ids
    assert listings["product_250"] not in ids

    # 3 Min + Max
    both = await client.get(
        "/search",
        params={"mode": "products", "min_price": 99, "max_price": 101},
    )
    assert both.status_code == 200
    ids = _product_ids(both)
    assert listings["product_99_5"] in ids
    assert listings["product_100"] in ids
    assert listings["product_50"] not in ids
    assert listings["product_250"] not in ids

    # 4 Exact price equal to minimum
    exact_min = await client.get(
        "/search",
        params={"mode": "products", "min_price": 100, "max_price": 500},
    )
    assert listings["product_100"] in _product_ids(exact_min)

    # 5 Exact price equal to maximum
    exact_max = await client.get(
        "/search",
        params={"mode": "products", "min_price": 50, "max_price": 100},
    )
    assert listings["product_100"] in _product_ids(exact_max)

    # 6 Price below minimum excluded
    below_min = await client.get("/search", params={"mode": "products", "min_price": 200})
    assert listings["product_100"] not in _product_ids(below_min)

    # 7 Price above maximum excluded
    above_max = await client.get("/search", params={"mode": "products", "max_price": 80})
    assert listings["product_100"] not in _product_ids(above_max)

    # 8 Decimal prices
    decimal_filter = await client.get(
        "/search",
        params={"mode": "products", "min_price": 99.5, "max_price": 99.5},
    )
    ids = _product_ids(decimal_filter)
    assert listings["product_99_5"] in ids
    assert listings["product_100"] not in ids

    # 10 Min > Max rejected
    invalid = await client.get(
        "/search",
        params={"mode": "products", "min_price": 500, "max_price": 100},
    )
    assert invalid.status_code == 422

    # 11 Clear price filter restores all products
    cleared = await client.get("/search", params={"mode": "products", "limit": 50})
    assert cleared.status_code == 200
    all_ids = _product_ids(cleared)
    for key in ("product_50", "product_99_5", "product_100", "product_250", "product_500"):
        assert listings[key] in all_ids

    # 12 Price + Category
    with_category = await client.get(
        "/search",
        params={"mode": "products", "category": "electronics", "min_price": 200},
    )
    assert listings["product_250"] in _product_ids(with_category)
    assert listings["product_50"] not in _product_ids(with_category)

    # 13 Price + City
    with_city = await client.get(
        "/search",
        params={"mode": "products", "city": "Casablanca", "max_price": 60},
    )
    assert listings["product_50"] in _product_ids(with_city)

    # 14 Price + Search
    with_search = await client.get(
        "/search",
        params={"mode": "products", "q": "Product 250", "min_price": 200},
    )
    ids = _product_ids(with_search)
    assert listings["product_250"] in ids
    assert listings["product_500"] not in ids

    # 15 Price + Relevance
    with_relevance = await client.get(
        "/search",
        params={"mode": "products", "sort": "relevance", "q": "Product", "max_price": 100},
    )
    assert listings["product_100"] in _product_ids(with_relevance)

    # 16 Price + Nearest
    with_nearest = await client.get(
        "/search",
        params={
            "mode": "products",
            "sort": "distance",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
            "min_price": 200,
            "limit": 20,
        },
    )
    assert with_nearest.status_code == 200, with_nearest.text
    assert listings["product_250"] in _product_ids(with_nearest)


@pytest.mark.asyncio
async def test_service_price_interval_filter_matrix(client: AsyncClient):
    listings = await _seed_price_catalog(client)

    # 1 Min only — fixed and range services whose upper bound meets the minimum
    min_only = await client.get("/search", params={"mode": "services", "min_price": 150})
    assert min_only.status_code == 200, min_only.text
    ids = _service_ids(min_only)
    assert listings["service_150"] in ids
    assert listings["service_range"] in ids
    assert listings["service_80"] not in ids
    assert listings["service_free"] not in ids
    assert listings["service_quote"] not in ids

    # 2 Max only
    max_only = await client.get("/search", params={"mode": "services", "max_price": 100})
    assert max_only.status_code == 200
    ids = _service_ids(max_only)
    assert listings["service_80"] in ids
    assert listings["service_free"] in ids
    assert listings["service_150"] not in ids
    assert listings["service_range"] not in ids

    # 3 Min + Max overlap with range-priced service
    both = await client.get(
        "/search",
        params={"mode": "services", "min_price": 250, "max_price": 350},
    )
    ids = _service_ids(both)
    assert listings["service_range"] in ids
    assert listings["service_150"] not in ids

    # 4 Exact minimum on fixed service
    exact_min = await client.get(
        "/search",
        params={"mode": "services", "min_price": 150, "max_price": 500},
    )
    assert listings["service_150"] in _service_ids(exact_min)

    # 5 Exact maximum on fixed service
    exact_max = await client.get(
        "/search",
        params={"mode": "services", "min_price": 50, "max_price": 150},
    )
    assert listings["service_150"] in _service_ids(exact_max)

    # 6 Below minimum excluded
    below_min = await client.get("/search", params={"mode": "services", "min_price": 500})
    assert listings["service_150"] not in _service_ids(below_min)

    # 7 Above maximum excluded
    above_max = await client.get("/search", params={"mode": "services", "max_price": 70})
    assert listings["service_150"] not in _service_ids(above_max)

    # 9 Price = 0 (free service)
    free_only = await client.get(
        "/search",
        params={"mode": "services", "max_price": 0},
    )
    assert listings["service_free"] in _service_ids(free_only)

    # 11 Clear restores all priced services
    cleared = await client.get("/search", params={"mode": "services", "limit": 50})
    all_ids = _service_ids(cleared)
    for key in ("service_80", "service_150", "service_range", "service_free", "service_quote"):
        assert listings[key] in all_ids

    # 12–16 Combined filters
    with_category = await client.get(
        "/search",
        params={"mode": "services", "category": "electronics", "min_price": 100},
    )
    assert listings["service_150"] in _service_ids(with_category)

    with_city = await client.get(
        "/search",
        params={"mode": "services", "city": "Casablanca", "max_price": 90},
    )
    assert listings["service_80"] in _service_ids(with_city)

    with_search = await client.get(
        "/search",
        params={"mode": "services", "q": "Range", "max_price": 500},
    )
    assert listings["service_range"] in _service_ids(with_search)

    with_relevance = await client.get(
        "/search",
        params={"mode": "services", "sort": "relevance", "q": "Service", "min_price": 140},
    )
    assert listings["service_150"] in _service_ids(with_relevance)

    with_nearest = await client.get(
        "/search",
        params={
            "mode": "services",
            "sort": "distance",
            "lat": ORIGIN_LAT,
            "lng": ORIGIN_LNG,
            "max_price": 100,
            "limit": 20,
        },
    )
    assert with_nearest.status_code == 200, with_nearest.text
    assert listings["service_80"] in _service_ids(with_nearest)


@pytest.mark.asyncio
async def test_price_range_service_trace_exclusion_bug(client: AsyncClient):
    """Trace: UI min=300 should include a 200–400 MAD range service via API overlap."""
    listings = await _seed_price_catalog(client)

    response = await client.get(
        "/search",
        params={"mode": "services", "min_price": 300, "max_price": 350},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    returned = next(
        (item for item in body["services"] if item["id"] == listings["service_range"]),
        None,
    )
    assert returned is not None, (
        "service_range has price_min_mad=200 and price_max_mad=400 in DB; "
        "min_price=300 requires price_max_mad >= 300 and max_price=350 requires "
        "price_min_mad <= 350, so the listing must be included"
    )


@pytest.mark.asyncio
async def test_product_and_service_modes_do_not_share_price_state(client: AsyncClient):
    listings = await _seed_price_catalog(client)

    products = await client.get(
        "/search",
        params={"mode": "products", "min_price": 400},
    )
    services = await client.get(
        "/search",
        params={"mode": "services", "max_price": 100},
    )
    products_again = await client.get(
        "/search",
        params={"mode": "products", "min_price": 400},
    )
    services_again = await client.get(
        "/search",
        params={"mode": "services", "max_price": 100},
    )

    assert listings["product_500"] in _product_ids(products)
    assert listings["service_80"] in _service_ids(services)
    assert _product_ids(products) == _product_ids(products_again)
    assert _service_ids(services) == _service_ids(services_again)
