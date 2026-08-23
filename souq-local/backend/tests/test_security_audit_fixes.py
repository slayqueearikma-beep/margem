"""Regression tests for security audit fixes."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _community_context(client: AsyncClient) -> dict:
    outsider = await register_test_user(
        client,
        email=f"outsider-{uuid4().hex[:8]}@example.com",
        account_type="buyer",
        display_name="Outsider",
    )
    member = await register_test_user(
        client,
        email=f"member-{uuid4().hex[:8]}@example.com",
        account_type="buyer",
        display_name="Member",
    )
    cities = (await client.get("/community/cities")).json()
    casablanca = next(c for c in cities if c["slug"] == "casablanca")
    join = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers={"Authorization": f"Bearer {member['access_token']}"},
        json={"is_home_city": True},
    )
    assert join.status_code == 200, join.text
    channels = (
        await client.get(
            f"/community/cities/{casablanca['slug']}/channels",
            headers={"Authorization": f"Bearer {member['access_token']}"},
        )
    ).json()
    general = next(ch for ch in channels if ch["category"] == "general")
    post = await client.post(
        f"/community/channels/{general['id']}/messages",
        headers={"Authorization": f"Bearer {member['access_token']}"},
        json={"body": "hello community"},
    )
    assert post.status_code in {200, 201}, post.text
    return {
        "outsider_headers": {"Authorization": f"Bearer {outsider['access_token']}"},
        "member_headers": {"Authorization": f"Bearer {member['access_token']}"},
        "channel_id": general["id"],
        "message_id": post.json()["id"],
    }


@pytest.mark.asyncio
async def test_community_reaction_requires_membership(client: AsyncClient):
    ctx = await _community_context(client)
    denied = await client.post(
        f"/community/messages/{ctx['message_id']}/reactions",
        headers=ctx["outsider_headers"],
        json={"emoji": "👍"},
    )
    assert denied.status_code == 403


@pytest.mark.asyncio
async def test_community_websocket_requires_membership(client: AsyncClient):
    ctx = await _community_context(client)
    ticket_res = await client.post(
        f"/community/channels/{ctx['channel_id']}/ws-ticket",
        headers=ctx["member_headers"],
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]
    with pytest.raises(Exception):
        async with client.websocket_connect(
            f"/community/ws?channel_id={ctx['channel_id']}&ticket={ticket}"
        ) as ws:
            await ws.receive_text()
    denied_ticket = await client.post(
        f"/community/channels/{ctx['channel_id']}/ws-ticket",
        headers=ctx["outsider_headers"],
    )
    assert denied_ticket.status_code == 403


@pytest.mark.asyncio
async def test_manual_billing_blocked_on_staging(client: AsyncClient, monkeypatch):
    user = await register_test_user(
        client,
        email=f"billing-{uuid4().hex[:8]}@example.com",
        account_type="buyer",
    )
    monkeypatch.setattr(settings, "app_env", "staging")
    monkeypatch.setattr(settings, "allow_manual_billing", False)
    monkeypatch.setattr(settings, "stripe_secret_key", "")
    headers = {"Authorization": f"Bearer {user['access_token']}"}
    res = await client.post(
        "/subscriptions/subscribe/buyer_premium",
        headers=headers,
        json={"subscription_terms_accepted": True},
    )
    assert res.status_code == 503


@pytest.mark.asyncio
async def test_signup_otp_phone_channel_unconfigured(client: AsyncClient):
    """Home server may run without SMS; OTP is logged instead of failing signup."""
    res = await client.post(
        "/auth/signup/otp/send",
        json={
            "email": f"phone-{uuid4().hex[:8]}@example.com",
            "phone": "+212600000099",
            "channel": "phone",
        },
    )
    assert res.status_code == 200
    body = res.json()
    assert body.get("channel") == "phone"
