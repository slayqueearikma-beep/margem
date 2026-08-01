"""Production readiness tests."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import User
from app.services.security import revoke_all_refresh_tokens
from tests.factories import seller_create_payload


async def _register_buyer(client: AsyncClient, email: str = "export-test@example.com") -> dict:
    password = "SecurePass1"
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": "buyer",
            "display_name": "Export Test",
        },
    )
    assert response.status_code == 201
    body = response.json()
    return {
        "email": email,
        "password": password,
        "access_token": body["access_token"],
    }


async def _register_seller(client: AsyncClient, email: str) -> dict:
    password = "SecurePass1"
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": "seller",
            "display_name": "Seller Test",
        },
    )
    assert response.status_code == 201
    body = response.json()
    return {
        "email": email,
        "password": password,
        "access_token": body["access_token"],
    }


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_change_password_enforces_strength() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client, "pwd-test@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        response = await client.post(
            "/auth/me/password",
            json={"current_password": user["password"], "new_password": "weakpass"},
            headers=headers,
        )
        assert response.status_code == 422


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_data_export_requires_auth() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/auth/me/export")
        assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_data_export_returns_account() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client)
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        response = await client.get("/auth/me/export", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert "account" in body
        assert body["account"]["email"] == user["email"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_saved_search_limit_for_free_users() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client, "saved-search@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        for i in range(3):
            response = await client.post(
                "/saved-searches",
                json={"query": f"shop {i}", "city": "Casablanca", "category": ""},
                headers=headers,
            )
            assert response.status_code == 201
        response = await client.post(
            "/saved-searches",
            json={"query": "shop overflow", "city": "Casablanca", "category": ""},
            headers=headers,
        )
        assert response.status_code == 403


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_access_token_revoked_after_session_revocation() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client, "revoke-test@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        me = await client.get("/auth/me", headers=headers)
        assert me.status_code == 200

        async with database.SessionLocal() as session:
            db_user = (
                await session.execute(select(User).where(User.email == user["email"]))
            ).scalar_one()
            await revoke_all_refresh_tokens(session, db_user.id)
            await session.commit()

        me2 = await client.get("/auth/me", headers=headers)
        assert me2.status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_non_premium_cannot_feature_product() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register_seller(client, "seller-feature@example.com")
        headers = {"Authorization": f"Bearer {seller['access_token']}"}
        profile = await client.post(
            "/sellers",
            headers=headers,
            json=seller_create_payload(
                business_name="Feature Shop",
                description="Test",
                address="1 Test St",
                phone="+212600000001",
                whatsapp_number="+212600000001",
            ),
        )
        assert profile.status_code == 201, profile.text
        seller_id = profile.json()["id"]
        product = await client.post(
            f"/sellers/{seller_id}/products",
            headers=headers,
            json={
                "name": "Featured Item",
                "description": "Test",
                "category_slug": "food",
                "price_mad": 10,
                "is_featured": True,
            },
        )
        assert product.status_code == 403, product.text


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_admin_list_endpoints_return_pagination() -> None:
    from uuid import uuid4

    from app.models import UserRole

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_email = f"admin-{uuid4().hex[:8]}@example.com"
        admin = await _register_buyer(client, admin_email)
        headers = {"Authorization": f"Bearer {admin['access_token']}"}
        async with database.SessionLocal() as session:
            user = (await session.execute(select(User).where(User.email == admin_email))).scalar_one()
            user.role = UserRole.ADMIN
            await session.commit()

        reports = await client.get("/admin/reports", headers=headers)
        assert reports.status_code == 200
        body = reports.json()
        assert "items" in body and "total" in body
