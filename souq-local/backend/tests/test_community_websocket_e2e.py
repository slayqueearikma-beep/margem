"""End-to-end WebSocket tests for city community chat."""

from __future__ import annotations

import json
from uuid import UUID, uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from starlette.testclient import TestClient

import app.database as database
from app.main import app
from app.models import User, UserRole
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _make_admin(user_id: str) -> None:
    async with database.SessionLocal() as session:
        user = await session.get(User, UUID(user_id))
        user.role = UserRole.ADMIN
        await session.commit()


async def _join_casablanca(client: AsyncClient, headers: dict) -> tuple[str, str]:
    cities = (await client.get("/community/cities")).json()
    casablanca = next(c for c in cities if c["slug"] == "casablanca")
    join = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers=headers,
        json={"is_home_city": True},
    )
    assert join.status_code == 200, join.text
    channels = (
        await client.get(
            f"/community/cities/{casablanca['slug']}/channels",
            headers=headers,
        )
    ).json()
    general = next(ch for ch in channels if ch["category"] == "general")
    return casablanca["slug"], general["id"]


@pytest.mark.asyncio
async def test_community_websocket_delivers_message_new(client: AsyncClient):
    listener = await register_test_user(
        client,
        email=f"ws-listener-{uuid4().hex[:8]}@example.com",
        display_name="Listener",
    )
    poster = await register_test_user(
        client,
        email=f"ws-poster-{uuid4().hex[:8]}@example.com",
        display_name="Poster",
    )
    listener_headers = {"Authorization": f"Bearer {listener['access_token']}"}
    poster_headers = {"Authorization": f"Bearer {poster['access_token']}"}

    city_slug, channel_id = await _join_casablanca(client, listener_headers)
    await _join_casablanca(client, poster_headers)

    ticket_res = await client.post(
        f"/community/channels/{channel_id}/ws-ticket",
        headers=listener_headers,
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]

    with TestClient(app) as tc:
        with tc.websocket_connect(
            f"/community/ws?channel_id={channel_id}&ticket={ticket}&city_slug={city_slug}"
        ) as ws:
            post = await client.post(
                f"/community/channels/{channel_id}/messages",
                headers=poster_headers,
                json={"body": "live websocket update"},
            )
            assert post.status_code == 201, post.text

            received = ws.receive_text()
            event = json.loads(received)
            assert event["type"] == "message.new"
            assert event["payload"]["body"] == "live websocket update"


@pytest.mark.asyncio
async def test_suspended_user_cannot_join_post_or_ws_ticket(client: AsyncClient):
    target = await register_test_user(
        client,
        email=f"suspended-{uuid4().hex[:8]}@example.com",
        display_name="Suspended User",
    )
    admin = await register_test_user(
        client,
        email=f"admin-{uuid4().hex[:8]}@example.com",
        display_name="Admin User",
    )
    target_headers = {"Authorization": f"Bearer {target['access_token']}"}
    admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}

    cities = (await client.get("/community/cities")).json()
    casablanca = next(c for c in cities if c["slug"] == "casablanca")
    channels = (
        await client.get(
            f"/community/cities/{casablanca['slug']}/channels",
            headers=target_headers,
        )
    ).json()
    channel_id = next(ch for ch in channels if ch["category"] == "general")["id"]

    join_before = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers=target_headers,
        json={"is_home_city": True},
    )
    assert join_before.status_code == 200, join_before.text

    await _make_admin(admin["user"]["id"])
    suspend = await client.patch(
        f"/admin/users/{target['user']['id']}/status",
        headers=admin_headers,
        params={"status": "suspended"},
    )
    assert suspend.status_code == 204, suspend.text

    join_after = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers=target_headers,
        json={"is_home_city": True},
    )
    assert join_after.status_code in {401, 403}

    post = await client.post(
        f"/community/channels/{channel_id}/messages",
        headers=target_headers,
        json={"body": "should fail"},
    )
    assert post.status_code in {401, 403}

    ticket = await client.post(
        f"/community/channels/{channel_id}/ws-ticket",
        headers=target_headers,
    )
    assert ticket.status_code in {401, 403}


@pytest.mark.asyncio
async def test_city_ban_blocks_post_and_ws_ticket(client: AsyncClient):
    staff = await register_test_user(
        client,
        email=f"staff-{uuid4().hex[:8]}@example.com",
        display_name="Staff User",
    )
    member = await register_test_user(
        client,
        email=f"banned-{uuid4().hex[:8]}@example.com",
        display_name="Banned User",
    )
    staff_headers = {"Authorization": f"Bearer {staff['access_token']}"}
    member_headers = {"Authorization": f"Bearer {member['access_token']}"}

    city_slug, channel_id = await _join_casablanca(client, member_headers)
    await _make_admin(staff["user"]["id"])

    ban = await client.post(
        f"/community/cities/{city_slug}/ban",
        headers=staff_headers,
        json={"user_id": member["user"]["id"], "reason": "spam"},
    )
    assert ban.status_code == 204, ban.text

    post = await client.post(
        f"/community/channels/{channel_id}/messages",
        headers=member_headers,
        json={"body": "should be blocked"},
    )
    assert post.status_code == 403

    ticket = await client.post(
        f"/community/channels/{channel_id}/ws-ticket",
        headers=member_headers,
    )
    assert ticket.status_code == 403


@pytest.mark.asyncio
async def test_suspended_user_cannot_connect_with_existing_ws_ticket(client: AsyncClient):
    user = await register_test_user(
        client,
        email=f"ws-suspend-{uuid4().hex[:8]}@example.com",
        display_name="Ws Suspend",
    )
    admin = await register_test_user(
        client,
        email=f"ws-admin-{uuid4().hex[:8]}@example.com",
        display_name="Ws Admin",
    )
    user_headers = {"Authorization": f"Bearer {user['access_token']}"}
    admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}

    city_slug, channel_id = await _join_casablanca(client, user_headers)
    ticket_res = await client.post(
        f"/community/channels/{channel_id}/ws-ticket",
        headers=user_headers,
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]

    await _make_admin(admin["user"]["id"])
    suspend = await client.patch(
        f"/admin/users/{user['user']['id']}/status",
        headers=admin_headers,
        params={"status": "suspended"},
    )
    assert suspend.status_code == 204, suspend.text

    with TestClient(app) as tc:
        with pytest.raises(Exception):
            with tc.websocket_connect(
                f"/community/ws?channel_id={channel_id}&ticket={ticket}&city_slug={city_slug}"
            ) as ws:
                ws.receive_text()


@pytest.mark.asyncio
async def test_community_websocket_reconnect_receives_messages(client: AsyncClient):
    listener = await register_test_user(
        client,
        email=f"ws-reconnect-{uuid4().hex[:8]}@example.com",
        display_name="Reconnect Listener",
    )
    poster = await register_test_user(
        client,
        email=f"ws-reconnect-poster-{uuid4().hex[:8]}@example.com",
        display_name="Reconnect Poster",
    )
    listener_headers = {"Authorization": f"Bearer {listener['access_token']}"}
    poster_headers = {"Authorization": f"Bearer {poster['access_token']}"}

    city_slug, channel_id = await _join_casablanca(client, listener_headers)
    await _join_casablanca(client, poster_headers)

    ticket_res = await client.post(
        f"/community/channels/{channel_id}/ws-ticket",
        headers=listener_headers,
    )
    assert ticket_res.status_code == 200, ticket_res.text
    ticket = ticket_res.json()["ticket"]

    with TestClient(app) as tc:
        with tc.websocket_connect(
            f"/community/ws?channel_id={channel_id}&ticket={ticket}&city_slug={city_slug}"
        ):
            pass

        ticket_res_2 = await client.post(
            f"/community/channels/{channel_id}/ws-ticket",
            headers=listener_headers,
        )
        assert ticket_res_2.status_code == 200, ticket_res_2.text
        ticket_2 = ticket_res_2.json()["ticket"]

        with tc.websocket_connect(
            f"/community/ws?channel_id={channel_id}&ticket={ticket_2}&city_slug={city_slug}"
        ) as ws:
            post = await client.post(
                f"/community/channels/{channel_id}/messages",
                headers=poster_headers,
                json={"body": "after reconnect"},
            )
            assert post.status_code == 201, post.text

            received = ws.receive_text()
            event = json.loads(received)
            assert event["type"] == "message.new"
            assert event["payload"]["body"] == "after reconnect"
