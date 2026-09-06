"""End-to-end WebSocket tests for marketplace community chat."""

from __future__ import annotations

import json
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from starlette.testclient import TestClient

from app.main import app
from tests.auth_helpers import register_test_user
from tests.test_marketplace_community import _seed_marketplace

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _join_marketplace(
    client: AsyncClient, slug: str, headers: dict
) -> tuple[str, str]:
    join = await client.post(f"/marketplaces/{slug}/community/join", headers=headers)
    assert join.status_code == 200, join.text
    channels = await client.get(
        f"/marketplaces/{slug}/community/channels",
        headers=headers,
    )
    assert channels.status_code == 200, channels.text
    channel_id = channels.json()[0]["id"]
    return slug, channel_id


@pytest.mark.asyncio
async def test_marketplace_websocket_delivers_message_new(client: AsyncClient):
    slug = await _seed_marketplace()
    listener = await register_test_user(
        client,
        email=f"mp-ws-listener-{uuid4().hex[:8]}@example.com",
        display_name="MP Listener",
    )
    poster = await register_test_user(
        client,
        email=f"mp-ws-poster-{uuid4().hex[:8]}@example.com",
        display_name="MP Poster",
    )
    listener_headers = {"Authorization": f"Bearer {listener['access_token']}"}
    poster_headers = {"Authorization": f"Bearer {poster['access_token']}"}

    marketplace_slug, channel_id = await _join_marketplace(
        client, slug, listener_headers
    )
    await _join_marketplace(client, slug, poster_headers)

    ticket_res = await client.post(
        f"/marketplaces/community/channels/{channel_id}/ws-ticket",
        headers=listener_headers,
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]

    with TestClient(app) as tc:
        with tc.websocket_connect(
            f"/marketplaces/community/ws?channel_id={channel_id}&ticket={ticket}&marketplace_slug={marketplace_slug}"
        ) as ws:
            post = await client.post(
                f"/marketplaces/community/channels/{channel_id}/messages",
                headers=poster_headers,
                json={"body": "marketplace live update", "post_type": "general"},
            )
            assert post.status_code == 201, post.text

            received = ws.receive_text()
            event = json.loads(received)
            assert event["type"] == "message.new"
            assert event["payload"]["body"] == "marketplace live update"


@pytest.mark.asyncio
async def test_marketplace_websocket_reconnect_receives_messages(client: AsyncClient):
    slug = await _seed_marketplace()
    listener = await register_test_user(
        client,
        email=f"mp-reconnect-{uuid4().hex[:8]}@example.com",
        display_name="MP Reconnect",
    )
    poster = await register_test_user(
        client,
        email=f"mp-reconnect-poster-{uuid4().hex[:8]}@example.com",
        display_name="MP Poster",
    )
    listener_headers = {"Authorization": f"Bearer {listener['access_token']}"}
    poster_headers = {"Authorization": f"Bearer {poster['access_token']}"}

    marketplace_slug, channel_id = await _join_marketplace(
        client, slug, listener_headers
    )
    await _join_marketplace(client, slug, poster_headers)

    ticket_res = await client.post(
        f"/marketplaces/community/channels/{channel_id}/ws-ticket",
        headers=listener_headers,
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]

    with TestClient(app) as tc:
        with tc.websocket_connect(
            f"/marketplaces/community/ws?channel_id={channel_id}&ticket={ticket}&marketplace_slug={marketplace_slug}"
        ):
            pass

        ticket_res_2 = await client.post(
            f"/marketplaces/community/channels/{channel_id}/ws-ticket",
            headers=listener_headers,
        )
        assert ticket_res_2.status_code == 200, ticket_res_2.text
        ticket_2 = ticket_res_2.json()["ticket"]

        with tc.websocket_connect(
            f"/marketplaces/community/ws?channel_id={channel_id}&ticket={ticket_2}&marketplace_slug={marketplace_slug}"
        ) as ws:
            post = await client.post(
                f"/marketplaces/community/channels/{channel_id}/messages",
                headers=poster_headers,
                json={"body": "marketplace after reconnect", "post_type": "general"},
            )
            assert post.status_code == 201, post.text

            received = ws.receive_text()
            event = json.loads(received)
            assert event["type"] == "message.new"
            assert event["payload"]["body"] == "marketplace after reconnect"


@pytest.mark.asyncio
async def test_marketplace_non_member_cannot_get_ws_ticket(client: AsyncClient):
    slug = await _seed_marketplace()
    member = await register_test_user(
        client,
        email=f"mp-member-{uuid4().hex[:8]}@example.com",
        display_name="MP Member",
    )
    outsider = await register_test_user(
        client,
        email=f"mp-outsider-{uuid4().hex[:8]}@example.com",
        display_name="MP Outsider",
    )
    member_headers = {"Authorization": f"Bearer {member['access_token']}"}
    outsider_headers = {"Authorization": f"Bearer {outsider['access_token']}"}

    _, channel_id = await _join_marketplace(client, slug, member_headers)

    denied = await client.post(
        f"/marketplaces/community/channels/{channel_id}/ws-ticket",
        headers=outsider_headers,
    )
    assert denied.status_code == 403

    allowed = await client.post(
        f"/marketplaces/community/channels/{channel_id}/ws-ticket",
        headers=member_headers,
    )
    assert allowed.status_code == 200, allowed.text
