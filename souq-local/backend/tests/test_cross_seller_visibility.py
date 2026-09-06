"""Cross-seller public listing visibility and authorization."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str) -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    normalized = "provider" if account_type == "seller" else account_type
    tokens = await register_test_user(
        client,
        email=email,
        account_type=normalized,
        display_name=account_type.title(),
    )
    return {
        "headers": {"Authorization": f"Bearer {tokens['access_token']}"},
        "token": tokens["access_token"],
    }


async def _create_public_listings(
    client: AsyncClient,
    headers: dict,
    *,
    business_name: str,
    product_name: str,
    service_name: str,
    marketplace_slug: str | None = None,
) -> tuple[dict, dict, dict]:
    payload = seller_create_payload(business_name=business_name)
    if marketplace_slug is not None:
        payload["marketplace_slug"] = marketplace_slug
    seller = await create_test_seller(client, headers, **payload)
    product = await client.post(
        f"/sellers/{seller['id']}/products",
        headers=headers,
        json={
            "name": product_name,
            "description": "Public product",
            "price_mad": 100,
            "price_negotiable": False,
        },
    )
    assert product.status_code == 201, product.text
    service = await client.post(
        f"/sellers/{seller['id']}/services",
        headers=headers,
        json={
            "name": service_name,
            "description": "Public service",
            "price_mad": 200,
        },
    )
    assert service.status_code == 201, service.text
    return seller, product.json(), service.json()


@pytest.mark.asyncio
async def test_buyer_sees_public_listings_from_multiple_sellers(client: AsyncClient):
    seller_a = await _register(client, "seller")
    seller_b = await _register(client, "seller")
    buyer = await _register(client, "buyer")

    _, product_a, service_a = await _create_public_listings(
        client,
        seller_a["headers"],
        business_name="Shop Alpha",
        product_name="Alpha Widget",
        service_name="Alpha Repair",
    )
    _, product_b, service_b = await _create_public_listings(
        client,
        seller_b["headers"],
        business_name="Shop Beta",
        product_name="Beta Gadget",
        service_name="Beta Cleaning",
    )

    search = await client.get("/search", params={"mode": "all", "limit": 50})
    assert search.status_code == 200, search.text
    body = search.json()
    product_ids = {item["id"] for item in body["products"]}
    service_ids = {item["id"] for item in body["services"]}
    assert product_a["id"] in product_ids
    assert product_b["id"] in product_ids
    assert service_a["id"] in service_ids
    assert service_b["id"] in service_ids

    buyer_search = await client.get(
        "/search",
        params={"mode": "all", "limit": 50},
        headers=buyer["headers"],
    )
    assert buyer_search.status_code == 200, buyer_search.text
    buyer_body = buyer_search.json()
    assert product_a["id"] in {item["id"] for item in buyer_body["products"]}
    assert product_b["id"] in {item["id"] for item in buyer_body["products"]}
    assert service_a["id"] in {item["id"] for item in buyer_body["services"]}
    assert service_b["id"] in {item["id"] for item in buyer_body["services"]}

    services_page = await client.get("/services", params={"limit": 50})
    assert services_page.status_code == 200, services_page.text
    listed_service_ids = {item["id"] for item in services_page.json()["items"]}
    assert service_a["id"] in listed_service_ids
    assert service_b["id"] in listed_service_ids

    for product_id in (product_a["id"], product_b["id"]):
        detail = await client.get(f"/products/{product_id}")
        assert detail.status_code == 200, detail.text

    for service_id in (service_a["id"], service_b["id"]):
        detail = await client.get(f"/services/{service_id}")
        assert detail.status_code == 200, detail.text


@pytest.mark.asyncio
async def test_search_without_marketplace_shows_all_casablanca_sellers(client: AsyncClient):
    from tests.seller_helpers import DEFAULT_TEST_MARKETPLACE_SLUG

    seller_a = await _register(client, "seller")
    seller_b = await _register(client, "seller")

    _, product_a, _ = await _create_public_listings(
        client,
        seller_a["headers"],
        business_name="Market Alpha",
        product_name="Alpha Scoped Product",
        service_name="Alpha Scoped Service",
        marketplace_slug=DEFAULT_TEST_MARKETPLACE_SLUG,
    )
    _, product_b, _ = await _create_public_listings(
        client,
        seller_b["headers"],
        business_name="Market Beta",
        product_name="Beta Scoped Product",
        service_name="Beta Scoped Service",
        marketplace_slug=DEFAULT_TEST_MARKETPLACE_SLUG,
    )

    unscoped = await client.get("/search", params={"mode": "products", "limit": 50})
    assert unscoped.status_code == 200, unscoped.text
    unscoped_ids = {item["id"] for item in unscoped.json()["products"]}
    assert product_a["id"] in unscoped_ids
    assert product_b["id"] in unscoped_ids

    scoped = await client.get(
        "/search",
        params={
            "mode": "products",
            "limit": 50,
            "marketplace": DEFAULT_TEST_MARKETPLACE_SLUG,
        },
    )
    assert scoped.status_code == 200, scoped.text
    scoped_ids = {item["id"] for item in scoped.json()["products"]}
    assert product_a["id"] in scoped_ids
    assert product_b["id"] in scoped_ids


@pytest.mark.asyncio
async def test_seller_cannot_mutate_other_sellers_listings(client: AsyncClient):
    seller_a = await _register(client, "seller")
    seller_b = await _register(client, "seller")

    shop_a, product_a, service_a = await _create_public_listings(
        client,
        seller_a["headers"],
        business_name="Owner Shop",
        product_name="Owned Product",
        service_name="Owned Service",
    )
    await _create_public_listings(
        client,
        seller_b["headers"],
        business_name="Other Shop",
        product_name="Other Product",
        service_name="Other Service",
    )

    patch_product = await client.patch(
        f"/sellers/{shop_a['id']}/products/{product_a['id']}",
        headers=seller_b["headers"],
        json={"name": "Hijacked"},
    )
    assert patch_product.status_code == 404

    delete_product = await client.delete(
        f"/sellers/{shop_a['id']}/products/{product_a['id']}",
        headers=seller_b["headers"],
    )
    assert delete_product.status_code == 404

    patch_service = await client.patch(
        f"/sellers/{shop_a['id']}/services/{service_a['id']}",
        headers=seller_b["headers"],
        json={"name": "Hijacked Service"},
    )
    assert patch_service.status_code == 404

    delete_service = await client.delete(
        f"/sellers/{shop_a['id']}/services/{service_a['id']}",
        headers=seller_b["headers"],
    )
    assert delete_service.status_code == 404


@pytest.mark.asyncio
async def test_hidden_unavailable_listings_stay_hidden(client: AsyncClient):
    seller = await _register(client, "seller")
    shop, product, service = await _create_public_listings(
        client,
        seller["headers"],
        business_name="Moderation Shop",
        product_name="Visible Product",
        service_name="Visible Service",
    )

    hidden = await client.post(
        f"/sellers/{shop['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Hidden Product",
            "description": "Should not appear",
            "price_mad": 50,
        },
    )
    assert hidden.status_code == 201, hidden.text
    hidden_id = hidden.json()["id"]
    hide = await client.patch(
        f"/sellers/{shop['id']}/products/{hidden_id}",
        headers=seller["headers"],
        json={"is_hidden": True},
    )
    assert hide.status_code == 200, hide.text

    unavailable = await client.patch(
        f"/sellers/{shop['id']}/products/{product['id']}",
        headers=seller["headers"],
        json={"is_available": False},
    )
    assert unavailable.status_code == 200, unavailable.text

    unavailable_service = await client.patch(
        f"/sellers/{shop['id']}/services/{service['id']}",
        headers=seller["headers"],
        json={"is_available": False},
    )
    assert unavailable_service.status_code == 200, unavailable_service.text

    search = await client.get("/search", params={"mode": "all", "limit": 50})
    assert search.status_code == 200, search.text
    body = search.json()
    product_ids = {item["id"] for item in body["products"]}
    service_ids = {item["id"] for item in body["services"]}
    assert hidden_id not in product_ids
    assert product["id"] not in product_ids
    assert service["id"] not in service_ids

    assert (await client.get(f"/products/{hidden_id}")).status_code == 404
    assert (await client.get(f"/products/{product['id']}")).status_code == 404
    assert (await client.get(f"/services/{service['id']}")).status_code == 404
