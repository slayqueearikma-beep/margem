"""Email verification token hygiene."""

from __future__ import annotations

from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select

import app.database as database
from app.models import AuthToken

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient) -> dict:
    email = f"verify-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "buyer",
            "display_name": "Verify User",
        },
    )
    assert res.status_code == 201, res.text
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {res.json()['access_token']}"},
    }


@pytest.mark.asyncio
async def test_new_verification_request_invalidates_previous_tokens(client: AsyncClient):
    user = await _register(client)
    first = await client.post("/auth/verify-email/request", headers=user["headers"])
    assert first.status_code == 204

    async with database.SessionLocal() as session:
        active_before = (
            await session.execute(
                select(AuthToken).where(
                    AuthToken.purpose == "email_verify",
                    AuthToken.used_at.is_(None),
                )
            )
        ).scalars().all()
        assert len(active_before) == 1
        first_hash = active_before[0].token_hash

    second = await client.post("/auth/verify-email/request", headers=user["headers"])
    assert second.status_code == 204

    async with database.SessionLocal() as session:
        active_after = (
            await session.execute(
                select(AuthToken).where(
                    AuthToken.purpose == "email_verify",
                    AuthToken.used_at.is_(None),
                )
            )
        ).scalars().all()
        assert len(active_after) == 1
        assert active_after[0].token_hash != first_hash
