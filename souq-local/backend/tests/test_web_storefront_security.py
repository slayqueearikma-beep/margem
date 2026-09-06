"""Security regression tests for public web storefront API surfaces."""

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


async def _register_seller(client: AsyncClient) -> dict:
    seller = await register_test_user(
        client,
        email=f"websec-{uuid4().hex[:8]}@example.com",
        account_type="seller",
        display_name="WebSec Seller",
    )
    headers = {"Authorization": f"Bearer {seller['access_token']}"}
    shop = await create_test_seller(
        client,
        headers,
        **seller_create_payload(
            business_name="Web Security Shop",
            website_url="https://example.com",
        ),
    )
    product = await client.post(
        f"/sellers/{shop['id']}/products",
        headers=headers,
        json={
            "name": "Secure Item",
            "description": "Listed product",
            "price_mad": 50,
        },
    )
    assert product.status_code == 201, product.text
    return {"seller": shop, "product": product.json(), "headers": headers}


@pytest.mark.asyncio
async def test_public_seller_detail_does_not_expose_owner_email(client: AsyncClient):
    fixtures = await _register_seller(client)
    seller_id = fixtures["seller"]["id"]

    response = await client.get(f"/sellers/{seller_id}")
    assert response.status_code == 200, response.text
    payload = response.json()

    assert "email" not in payload
    assert payload["business_name"] == "Web Security Shop"
    assert payload["website_url"] == "https://example.com"


@pytest.mark.asyncio
async def test_public_product_detail_is_read_only_and_minimal(client: AsyncClient):
    fixtures = await _register_seller(client)
    product_id = fixtures["product"]["id"]

    response = await client.get(f"/products/{product_id}")
    assert response.status_code == 200, response.text
    payload = response.json()

    assert "product" in payload
    assert "seller" in payload
    assert "email" not in payload["seller"]
    assert "password" not in payload


@pytest.mark.asyncio
async def test_search_rejects_oversized_query(client: AsyncClient):
    oversized = "x" * 200
    response = await client.get("/search", params={"q": oversized})
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_public_catalog_endpoints_do_not_require_auth(client: AsyncClient):
    fixtures = await _register_seller(client)
    seller_id = fixtures["seller"]["id"]
    product_id = fixtures["product"]["id"]

    for path in (
        "/categories",
        "/search?q=Secure",
        f"/products/{product_id}",
        f"/sellers/{seller_id}",
        "/marketplaces",
        "/geography/cities?country=MA",
    ):
        response = await client.get(path)
        assert response.status_code == 200, f"{path}: {response.text}"


@pytest.mark.asyncio
async def test_auth_me_requires_bearer_token(client: AsyncClient):
    response = await client.get("/auth/me")
    assert response.status_code == 401
    assert response.json()["detail"] == "Missing bearer token"
