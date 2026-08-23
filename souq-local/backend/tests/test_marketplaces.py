"""Marketplace and per-marketplace category management."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models import UserRole
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


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


@pytest.mark.asyncio
async def test_public_marketplace_list_empty(client: AsyncClient):
    response = await client.get("/marketplaces")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_admin_marketplace_crud_and_categories(client: AsyncClient):
    headers = await _admin_headers(client)

    create = await client.post(
        "/admin/marketplaces",
        headers=headers,
        json={
            "name": "Derb Ghallef",
            "slug": "derb-ghallef",
            "description": "Electronics market",
            "address": "Derb Ghallef",
            "district": "Derb Ghallef",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.61,
            "display_order": 1,
            "is_active": True,
            "opening_hours": {"monday": {"open": "09:00", "close": "20:00", "closed": False}},
        },
    )
    assert create.status_code == 201, create.text
    marketplace = create.json()
    marketplace_id = marketplace["id"]

    listed = await client.get("/marketplaces")
    assert listed.status_code == 200
    assert any(item["slug"] == "derb-ghallef" for item in listed.json())

    cat_create = await client.post(
        f"/admin/marketplaces/{marketplace_id}/categories",
        headers=headers,
        json={
            "name": "Phones",
            "slug": "phones",
            "description": "Smartphones",
            "icon": "smartphone",
            "display_order": 0,
            "is_active": True,
        },
    )
    assert cat_create.status_code == 201, cat_create.text
    category = cat_create.json()

    categories = await client.get("/marketplaces/derb-ghallef/categories")
    assert categories.status_code == 200
    slugs = [item["slug"] for item in categories.json()]
    assert "phones" in slugs
    assert categories.json()[0]["name_en"] == "Phones"

    hide = await client.post(f"/admin/marketplaces/{marketplace_id}/hide", headers=headers)
    assert hide.status_code == 200
    assert hide.json()["is_active"] is False

    public = await client.get("/marketplaces")
    assert all(item["slug"] != "derb-ghallef" for item in public.json())

    unhide = await client.post(f"/admin/marketplaces/{marketplace_id}/unhide", headers=headers)
    assert unhide.status_code == 200

    reorder = await client.post(
        f"/admin/marketplaces/{marketplace_id}/categories/reorder",
        headers=headers,
        json={"ordered_ids": [category["id"]]},
    )
    assert reorder.status_code == 200

    admin_list = await client.get(
        "/admin/marketplaces",
        headers=headers,
        params={"search": "ghallef", "status_filter": "active"},
    )
    assert admin_list.status_code == 200
    payload = admin_list.json()
    assert payload["total"] >= 1
    assert payload["stats"]["active"] >= 1


@pytest.mark.asyncio
async def test_non_admin_cannot_manage_marketplaces(client: AsyncClient):
    body = await register_test_user(
        client,
        email=f"buyer-{uuid4().hex[:8]}@example.com",
        account_type="buyer",
        display_name="Buyer",
    )
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    response = await client.get("/admin/marketplaces", headers=headers)
    assert response.status_code == 403
