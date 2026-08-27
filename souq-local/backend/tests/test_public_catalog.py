"""Public catalog endpoints used by the web storefront."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str) -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": account_type,
            "display_name": account_type.title(),
        },
    )
    assert res.status_code == 201, res.text
    tokens = res.json()
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _create_seller_listings(client: AsyncClient) -> tuple[dict, dict]:
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json={
            "business_name": "Atlas Crafts",
            "description": "Handmade goods",
            "address": "12 Medina Street",
            "city": "Casablanca",
            "latitude": 31.63,
            "longitude": -8.0,
            "phone": "+212600000001",
            "website_url": "https://example.com",
        },
    )
    assert profile.status_code == 201, profile.text
    seller_body = profile.json()
    product = await client.post(
        f"/sellers/{seller_body['id']}/products",
        headers=seller["headers"],
        json={
            "name": "Ceramic Bowl",
            "description": "Hand-thrown",
            "price_mad": 120,
            "price_negotiable": True,
        },
    )
    assert product.status_code == 201, product.text
    service = await client.post(
        f"/sellers/{seller_body['id']}/services",
        headers=seller["headers"],
        json={
            "name": "Custom glazing",
            "description": "On-site glazing service",
            "price_mad": 250,
        },
    )
    assert service.status_code == 201, service.text
    return product.json(), service.json()


@pytest.mark.asyncio
async def test_public_product_detail(client: AsyncClient):
    product, _ = await _create_seller_listings(client)
    response = await client.get(f"/products/{product['id']}")
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["product"]["id"] == product["id"]
    assert payload["seller"]["business_name"] == "Atlas Crafts"


@pytest.mark.asyncio
async def test_public_service_detail(client: AsyncClient):
    _, service = await _create_seller_listings(client)
    response = await client.get(f"/services/{service['id']}")
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["service"]["id"] == service["id"]


@pytest.mark.asyncio
async def test_public_services_list(client: AsyncClient):
    _, service = await _create_seller_listings(client)
    response = await client.get("/services?limit=5")
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["total"] >= 1
    assert any(item["id"] == service["id"] for item in payload["items"])
