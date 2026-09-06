"""Casablanca market-first discovery tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models import UserRole
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _admin_headers(client: AsyncClient) -> dict:
    email = f"admin-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(
        client,
        email=email,
        account_type="buyer",
        display_name="Admin",
    )
    import app.database as database
    from sqlalchemy import select
    from app.models import User

    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.ADMIN
        await session.commit()
    return {"Authorization": f"Bearer {body['access_token']}"}


async def _seed_casablanca_markets(client: AsyncClient) -> None:
    headers = await _admin_headers(client)
    markets = [
        {
            "name": "Derb Ghallef",
            "slug": "derb-ghallef",
            "description": "Electronics market",
            "known_for": "Electronics, phones, repairs",
            "address": "Derb Ghallef",
            "district": "Derb Ghallef",
            "city": "Casablanca",
            "latitude": 33.5789,
            "longitude": -7.6100,
            "display_order": 1,
        },
        {
            "name": "Habous",
            "slug": "habous",
            "description": "Traditional crafts quarter",
            "known_for": "Leather, handicrafts, traditional clothing",
            "address": "Quartier Habous",
            "district": "Habous",
            "city": "Casablanca",
            "latitude": 33.5775,
            "longitude": -7.6128,
            "display_order": 4,
        },
        {
            "name": "Medina",
            "slug": "medina",
            "description": "Old medina commerce",
            "known_for": "Textiles, household goods",
            "address": "Medina",
            "district": "Medina",
            "city": "Casablanca",
            "latitude": 33.6031,
            "longitude": -7.6167,
            "display_order": 5,
        },
        {
            "name": "Bab Marrakech",
            "slug": "bab-marrakech",
            "description": "Central shopping district",
            "known_for": "Mixed retail and clothing",
            "address": "Bab Marrakech",
            "district": "Bab Marrakech",
            "city": "Casablanca",
            "latitude": 33.5958,
            "longitude": -7.6169,
            "display_order": 6,
        },
    ]
    for payload in markets:
        response = await client.post("/admin/marketplaces", headers=headers, json=payload)
        assert response.status_code == 201, response.text


async def _seed_other_casablanca_market(client: AsyncClient) -> None:
    headers = await _admin_headers(client)
    response = await client.post(
        "/admin/marketplaces",
        headers=headers,
        json={
            "name": "Other Casablanca Markets",
            "slug": "other-casablanca-markets",
            "description": "Casablanca commercial areas not yet listed as dedicated markets.",
            "known_for": "User-provided market or district names",
            "address": "Casablanca",
            "district": "Casablanca",
            "city": "Casablanca",
            "latitude": 33.5731,
            "longitude": -7.5898,
            "display_order": 99,
        },
    )
    assert response.status_code == 201, response.text


@pytest.mark.asyncio
async def test_casablanca_markets_include_habous():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await _seed_casablanca_markets(client)
        response = await client.get("/marketplaces", params={"city": "Casablanca"})
        assert response.status_code == 200
        slugs = {row["slug"] for row in response.json()}
        assert "derb-ghallef" in slugs
        assert "habous" in slugs
        assert "medina" in slugs
        assert "bab-marrakech" in slugs


@pytest.mark.asyncio
async def test_market_detail_includes_known_for():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await _seed_casablanca_markets(client)
        response = await client.get("/marketplaces/derb-ghallef")
        assert response.status_code == 200
        body = response.json()
        assert body["known_for"]
        assert body["seller_count"] >= 0


@pytest.mark.asyncio
async def test_seller_create_assigns_marketplace_and_stall_fields():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await _seed_casablanca_markets(client)
        email = f"stall-{uuid4().hex[:8]}@example.com"
        body = await register_test_user(client, email=email, account_type="seller")
        headers = {"Authorization": f"Bearer {body['access_token']}"}

        create = await client.post(
            "/sellers",
            headers=headers,
            json={
                "business_name": "Phone Shop Test",
                "description": "Electronics stall",
                "address": "Derb Ghallef, Casablanca",
                "city": "Casablanca",
                "latitude": 33.5789,
                "longitude": -7.6100,
                "phone": "+212600000000",
                "marketplace_slug": "derb-ghallef",
                "market_gallery": "Gallery A",
                "shop_number": "42",
                "seller_terms_acknowledged": True,
            },
        )
        assert create.status_code == 201, create.text
        payload = create.json()
        assert payload["marketplace_slug"] == "derb-ghallef"
        assert payload["shop_number"] == "42"
        assert "Gallery A" in payload["stall_location_summary"]


@pytest.mark.asyncio
async def test_seller_create_accepts_custom_market_name():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"custom-market-{uuid4().hex[:8]}@example.com"
        body = await register_test_user(client, email=email, account_type="seller")
        headers = {"Authorization": f"Bearer {body['access_token']}"}

        create = await client.post(
            "/sellers",
            headers=headers,
            json={
                "business_name": "Hay Shop",
                "description": "Local market stall",
                "address": "Hay Mohammadi, Casablanca",
                "city": "Casablanca",
                "latitude": 33.5731,
                "longitude": -7.5898,
                "phone": "+212600000001",
                "custom_marketplace_name": "Hay Mohammadi Souk",
                "seller_terms_acknowledged": True,
            },
        )
        assert create.status_code == 201, create.text
        payload = create.json()
        assert payload["custom_marketplace_name"] == "Hay Mohammadi Souk"
        assert payload["marketplace_name"] == "Hay Mohammadi Souk"
        assert payload["marketplace_slug"] == "other-casablanca-markets"
