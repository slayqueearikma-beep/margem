"""Security boundary regression tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import Notification, User, UserRole

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str | None = None) -> dict:
    address = email or f"sec-{uuid4().hex[:8]}@example.com"
    response = await client.post(
        "/auth/register",
        json={
            "email": address,
            "password": "SecurePass1",
            "account_type": "buyer",
            "display_name": "Sec User",
        },
    )
    assert response.status_code == 201, response.text
    body = response.json()
    return {
        "email": address,
        "access_token": body["access_token"],
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
    }


async def _verify_email(email: str) -> None:
    from datetime import UTC, datetime

    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.email_verified_at = datetime.now(UTC)
        await session.commit()


@pytest.mark.asyncio
async def test_cannot_read_other_users_notification():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        alice = await _register(client)
        bob = await _register(client)

        async with database.SessionLocal() as session:
            bob_user = (await session.execute(select(User).where(User.email == bob["email"]))).scalar_one()
            note = Notification(
                id=uuid4(),
                user_id=bob_user.id,
                title="Private",
                body="Secret",
                kind="system",
                data={},
            )
            session.add(note)
            await session.commit()
            note_id = note.id

        denied = await client.post(
            f"/notifications/{note_id}/read",
            headers=alice["headers"],
        )
        assert denied.status_code == 404


@pytest.mark.asyncio
async def test_cannot_modify_other_users_product():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller_a = await _register(client, f"seller-a-{uuid4().hex[:6]}@example.com")
        seller_b = await _register(client, f"seller-b-{uuid4().hex[:6]}@example.com")
        await _verify_email(seller_a["email"])
        await _verify_email(seller_b["email"])

        store_a = await client.post(
            "/sellers",
            headers=seller_a["headers"],
            json={
                "business_name": "Shop A",
                "description": "A",
                "address": "1 Main Street",
                "city": "Casablanca",
                "latitude": 33.57,
                "longitude": -7.62,
                "phone": "+212600000001",
                "whatsapp_number": "+212600000001",
                "payment_methods": ["cash"],
                "delivery_methods": ["in_store"],
                "cover_image_url": "",
                "category_ids": [],
            },
        )
        assert store_a.status_code == 201, store_a.text
        seller_id = store_a.json()["id"]

        product = await client.post(
            f"/sellers/{seller_id}/products",
            headers=seller_a["headers"],
            json={
                "name": "Widget",
                "description": "Test",
                "price_mad": 10,
                "is_available": True,
            },
        )
        assert product.status_code == 201, product.text
        product_id = product.json()["id"]

        tamper = await client.patch(
            f"/sellers/{seller_id}/products/{product_id}",
            headers=seller_b["headers"],
            json={"name": "Hacked"},
        )
        assert tamper.status_code in {403, 404}


@pytest.mark.asyncio
async def test_self_serve_premium_blocked_in_production(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "app_env", "production")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client)
        response = await client.post(
            "/subscriptions/subscribe/buyer_premium",
            headers=user["headers"],
        )
        assert response.status_code == 503


@pytest.mark.asyncio
async def test_admin_routes_blocked_without_ip_allowlist_in_production(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "admin_ip_allowlist", [])

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client)
        async with database.SessionLocal() as session:
            row = (await session.execute(select(User).where(User.email == user["email"]))).scalar_one()
            row.role = UserRole.ADMIN
            await session.commit()

        response = await client.get("/admin/users", headers=user["headers"])
        assert response.status_code == 403


@pytest.mark.asyncio
async def test_access_token_invalidated_after_password_change():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client)
        old_token = user["headers"]["Authorization"]

        change = await client.post(
            "/auth/me/password",
            headers=user["headers"],
            json={
                "current_password": "SecurePass1",
                "new_password": "NewSecurePass2",
            },
        )
        assert change.status_code == 204, change.text

        stale = await client.get("/auth/me", headers={"Authorization": old_token})
        assert stale.status_code == 401


@pytest.mark.asyncio
async def test_login_lockout_after_repeated_failures():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client)

        for _ in range(5):
            bad = await client.post(
                "/auth/login",
                json={"email": user["email"], "password": "WrongPass9"},
            )
            assert bad.status_code == 401

        locked = await client.post(
            "/auth/login",
            json={"email": user["email"], "password": "SecurePass1"},
        )
        assert locked.status_code == 429
