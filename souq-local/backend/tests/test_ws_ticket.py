"""WebSocket ticket issuance and verification."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.ws_ticket import (
    community_audience,
    issue_ws_ticket,
    marketplace_audience,
    verify_ws_ticket,
)
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


def test_ws_ticket_roundtrip():
    channel_id = uuid4()
    user_id = uuid4()
    ticket = issue_ws_ticket(user_id=user_id, channel_id=channel_id, audience=community_audience())
    verified = verify_ws_ticket(ticket, channel_id=channel_id, audience=community_audience())
    assert verified == user_id


def test_ws_ticket_rejects_wrong_channel():
    channel_id = uuid4()
    ticket = issue_ws_ticket(user_id=uuid4(), channel_id=channel_id, audience=community_audience())
    with pytest.raises(Exception):
        verify_ws_ticket(ticket, channel_id=uuid4(), audience=community_audience())


def test_ws_ticket_rejects_wrong_audience():
    channel_id = uuid4()
    ticket = issue_ws_ticket(user_id=uuid4(), channel_id=channel_id, audience=community_audience())
    with pytest.raises(Exception):
        verify_ws_ticket(ticket, channel_id=channel_id, audience=marketplace_audience())


@pytest.mark.asyncio
async def test_community_ws_ticket_endpoint_requires_membership(client: AsyncClient):
    user = await register_test_user(
        client,
        email=f"ws-user-{uuid4().hex[:8]}@example.com",
        account_type="buyer",
        display_name="Ws User",
    )
    headers = {"Authorization": f"Bearer {user['access_token']}"}
    cities = (await client.get("/community/cities")).json()
    casablanca = next(c for c in cities if c["slug"] == "casablanca")
    channels = (
        await client.get(f"/community/cities/{casablanca['slug']}/channels", headers=headers)
    ).json()
    general = next(ch for ch in channels if ch["category"] == "general")
    denied = await client.post(f"/community/channels/{general['id']}/ws-ticket", headers=headers)
    assert denied.status_code == 403

    join = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers=headers,
        json={"is_home_city": True},
    )
    assert join.status_code == 200, join.text
    allowed = await client.post(f"/community/channels/{general['id']}/ws-ticket", headers=headers)
    assert allowed.status_code == 200, allowed.text
    assert len(allowed.json()["ticket"]) >= 20
