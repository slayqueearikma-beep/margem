"""City community chat API tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.models import User, UserRole
from app.models.community import City, CommunityChannel, CommunityChannelCategory
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, name: str = "Community User") -> dict:
    email = f"community-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(
        client,
        email=email,
        password="SecurePass1",
        account_type="buyer",
        display_name=name,
    )
    return {
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
        "user_id": body["user"]["id"],
    }


async def _make_admin(session_factory, user_id: str) -> None:
    from uuid import UUID

    async with session_factory() as session:
        user = await session.get(User, UUID(user_id))
        user.role = UserRole.ADMIN
        await session.commit()


@pytest.mark.asyncio
async def test_list_cities_seeds_casablanca(client: AsyncClient):
    res = await client.get("/community/cities")
    assert res.status_code == 200
    cities = res.json()
    assert any(c["slug"] == "casablanca" for c in cities)


@pytest.mark.asyncio
async def test_join_city_and_post_message(client: AsyncClient):
    user = await _register(client)

    cities = (await client.get("/community/cities")).json()
    casablanca = next(c for c in cities if c["slug"] == "casablanca")

    join = await client.post(
        f"/community/cities/{casablanca['slug']}/join",
        headers=user["headers"],
        json={"is_home_city": True},
    )
    assert join.status_code == 200
    assert join.json()["is_member"] is True

    channels = (
        await client.get(
            f"/community/cities/{casablanca['slug']}/channels",
            headers=user["headers"],
        )
    ).json()
    general = next(ch for ch in channels if ch["category"] == "general")

    post = await client.post(
        f"/community/channels/{general['id']}/messages",
        headers=user["headers"],
        json={"body": "Hello Casablanca community!"},
    )
    assert post.status_code == 201
    payload = post.json()
    assert payload["body"] == "Hello Casablanca community!"
    assert payload["sender"]["display_name"] == "Community User"
    assert payload["sender"]["trust_score"] >= 30

    history = await client.get(
        f"/community/channels/{general['id']}/messages",
        headers=user["headers"],
    )
    assert history.status_code == 200
    assert len(history.json()) >= 1


@pytest.mark.asyncio
async def test_admin_create_and_delete_city(client: AsyncClient):
    import app.database as database

    user = await _register(client, name="Admin User")
    await _make_admin(database.SessionLocal, user["user_id"])

    slug = f"test-city-{uuid4().hex[:6]}"
    create = await client.post(
        "/community/admin/cities",
        headers=user["headers"],
        json={"slug": slug, "name": "Test City", "description": "Test community"},
    )
    assert create.status_code == 201
    assert create.json()["slug"] == slug

    channels = (
        await client.get(f"/community/cities/{slug}/channels", headers=user["headers"])
    ).json()
    assert len(channels) == 12

    delete = await client.delete(f"/community/admin/cities/{slug}", headers=user["headers"])
    assert delete.status_code == 204

    missing = await client.get(f"/community/cities/{slug}")
    assert missing.status_code == 404


@pytest.mark.asyncio
async def test_non_member_cannot_post_or_read_messages(client: AsyncClient):
    user = await _register(client)
    cities = (await client.get("/community/cities")).json()
    slug = next(c["slug"] for c in cities if c["slug"] == "casablanca")
    channels = (
        await client.get(f"/community/cities/{slug}/channels", headers=user["headers"])
    ).json()
    channel_id = channels[0]["id"]

    history = await client.get(
        f"/community/channels/{channel_id}/messages",
        headers=user["headers"],
    )
    assert history.status_code == 403

    post = await client.post(
        f"/community/channels/{channel_id}/messages",
        headers=user["headers"],
        json={"body": "Should not post without joining"},
    )
    assert post.status_code == 403


@pytest.mark.asyncio
async def test_reaction_and_report(client: AsyncClient):
    user = await _register(client)
    cities = (await client.get("/community/cities")).json()
    slug = next(c["slug"] for c in cities if c["slug"] == "casablanca")
    await client.post(f"/community/cities/{slug}/join", headers=user["headers"], json={})
    channels = (await client.get(f"/community/cities/{slug}/channels", headers=user["headers"])).json()
    channel_id = channels[0]["id"]

    message = (
        await client.post(
            f"/community/channels/{channel_id}/messages",
            headers=user["headers"],
            json={"body": "Great local bakery on Maarif!"},
        )
    ).json()

    react = await client.post(
        f"/community/messages/{message['id']}/reactions",
        headers=user["headers"],
        json={"emoji": "👍"},
    )
    assert react.status_code == 200

    report = await client.post(
        f"/community/messages/{message['id']}/report",
        headers=user["headers"],
        json={"reason": "spam", "details": "test"},
    )
    assert report.status_code == 201


@pytest.mark.asyncio
async def test_ensure_all_city_communities_is_idempotent():
    import app.database as database
    from app.services.community_chat import ensure_all_city_communities

    async with database.SessionLocal() as session:
        await ensure_all_city_communities(session)
        first_count = len((await session.scalars(select(CommunityChannel))).all())
        assert first_count > 0

        await ensure_all_city_communities(session)
        second_count = len((await session.scalars(select(CommunityChannel))).all())
        assert second_count == first_count
