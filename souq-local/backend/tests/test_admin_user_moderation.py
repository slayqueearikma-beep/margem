"""Admin user moderation tests."""

from __future__ import annotations

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import SellerProfile, User, UserRole, UserStatus
from tests.factories import seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str = "buyer") -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": account_type,
            "display_name": account_type.title(),
        },
    )
    assert res.status_code == 201, res.text
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {res.json()['access_token']}"},
    }


async def _set_role(email: str, role: UserRole) -> None:
    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = role
        await session.commit()


@pytest.mark.asyncio
async def test_moderator_cannot_suspend_users(client: AsyncClient):
    target = await _register(client)
    moderator = await _register(client)
    await _set_role(moderator["email"], UserRole.MODERATOR)
    me = await client.get("/auth/me", headers=target["headers"])
    user_id = me.json()["id"]

    res = await client.patch(
        f"/admin/users/{user_id}/status",
        headers=moderator["headers"],
        params={"status": "suspended"},
    )
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_admin_delete_user_soft_deletes_and_deactivates_store(client: AsyncClient):
    seller = await _register(client, "seller")
    profile = await client.post(
        "/sellers",
        headers=seller["headers"],
        json=seller_create_payload(business_name="Delete Me Shop"),
    )
    assert profile.status_code == 201, profile.text
    seller_id = profile.json()["id"]

    admin = await _register(client)
    await _set_role(admin["email"], UserRole.ADMIN)
    me = await client.get("/auth/me", headers=seller["headers"])
    user_id = me.json()["id"]

    deleted = await client.patch(
        f"/admin/users/{user_id}/status",
        headers=admin["headers"],
        params={"status": "deleted"},
    )
    assert deleted.status_code == 204, deleted.text

    async with database.SessionLocal() as session:
        user = await session.get(User, user_id)
        assert user is not None
        assert user.status == UserStatus.DELETED
        assert user.email.startswith("deleted+")
        store = await session.get(SellerProfile, seller_id)
        assert store is None

    public = await client.get(f"/sellers/{seller_id}")
    assert public.status_code == 404


@pytest.mark.asyncio
async def test_admin_cannot_suspend_self(client: AsyncClient):
    admin = await _register(client)
    await _set_role(admin["email"], UserRole.ADMIN)
    me = await client.get("/auth/me", headers=admin["headers"])
    user_id = me.json()["id"]

    res = await client.patch(
        f"/admin/users/{user_id}/status",
        headers=admin["headers"],
        params={"status": "suspended"},
    )
    assert res.status_code == 400
