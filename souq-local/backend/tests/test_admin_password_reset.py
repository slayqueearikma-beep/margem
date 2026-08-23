"""Admin-triggered password reset."""

from __future__ import annotations

from unittest.mock import patch
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select

import app.database as database
from app.models import UserRole

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient) -> dict:
    email = f"user-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "buyer",
            "display_name": "User",
        },
    )
    assert res.status_code == 201, res.text
    return {
        "email": email,
        "id": res.json()["user"]["id"],
        "headers": {"Authorization": f"Bearer {res.json()['access_token']}"},
    }


async def _promote_admin(email: str) -> None:
    async with database.SessionLocal() as session:
        from app.models import User

        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.ADMIN
        await session.commit()


@pytest.mark.asyncio
async def test_admin_trigger_password_reset_sends_email(client: AsyncClient):
    target = await _register(client)
    admin = await _register(client)
    await _promote_admin(admin["email"])

    with patch("app.routers.admin.email_service.send") as send_mock:
        res = await client.post(
            f"/admin/users/{target['id']}/reset-password",
            headers=admin["headers"],
        )
    assert res.status_code == 204, res.text
    send_mock.assert_called_once()
