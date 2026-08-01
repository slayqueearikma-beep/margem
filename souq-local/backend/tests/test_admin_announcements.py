"""Admin platform announcements."""

from __future__ import annotations

from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select

import app.database as database
from app.models import Notification, UserRole
from tests.factories import seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


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


async def _promote_admin(email: str) -> None:
    async with database.SessionLocal() as session:
        from app.models import User

        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.ADMIN
        await session.commit()


@pytest.mark.asyncio
async def test_admin_announcement_delivers_in_app_notifications(client: AsyncClient):
    buyer = await _register(client, "buyer")
    seller = await _register(client, "seller")
    await client.post(
        "/sellers",
        headers=seller["headers"],
        json=seller_create_payload(business_name="Announce Shop"),
    )
    admin = await _register(client, "buyer")
    await _promote_admin(admin["email"])

    res = await client.post(
        "/admin/announcements",
        headers=admin["headers"],
        json={"title": "Beta launch", "body": "Welcome to MarGem beta!", "audience": "all"},
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["sent"] >= 2

    async with database.SessionLocal() as session:
        notes = (await session.execute(select(Notification))).scalars().all()
        assert len(notes) >= 2
        assert any(n.title == "Beta launch" for n in notes)
