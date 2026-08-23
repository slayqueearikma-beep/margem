"""Marketplace-specific community hubs."""

from uuid import UUID, uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import Marketplace
from app.models.marketplace_community import MarketplaceCommunityChannel
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _user_headers(client: AsyncClient) -> dict:
    email = f"buyer-{uuid4().hex[:8]}@example.com"
    tokens = await register_test_user(client, email=email, account_type="buyer", display_name="Buyer")
    return {"Authorization": f"Bearer {tokens['access_token']}"}


async def _seed_marketplace() -> str:
    async with database.SessionLocal() as session:
        existing = await session.scalar(select(Marketplace).where(Marketplace.slug == "derb-ghallef"))
        if existing is None:
            mp_id = uuid4()
            session.add(
                Marketplace(
                    id=mp_id,
                    slug="derb-ghallef",
                    name="Derb Ghallef",
                    description="Electronics market",
                    city="Casablanca",
                )
            )
            await session.commit()
        else:
            mp_id = existing.id
        return "derb-ghallef"


@pytest.mark.asyncio
async def test_marketplace_community_channels_seeded(client: AsyncClient):
    slug = await _seed_marketplace()
    response = await client.get(f"/marketplaces/{slug}/community/channels")
    assert response.status_code == 200, response.text
    names = {item["name"] for item in response.json()}
    assert "General" in names
    assert "Phones" in names
    assert "Gaming" in names


@pytest.mark.asyncio
async def test_marketplace_community_join_and_post(client: AsyncClient):
    slug = await _seed_marketplace()
    headers = await _user_headers(client)

    join = await client.post(f"/marketplaces/{slug}/community/join", headers=headers)
    assert join.status_code == 200, join.text

    channels = await client.get(f"/marketplaces/{slug}/community/channels", headers=headers)
    channel_id = channels.json()[0]["id"]

    post = await client.post(
        f"/marketplaces/community/channels/{channel_id}/messages",
        headers=headers,
        json={"body": "Any good phone deals today?", "post_type": "question"},
    )
    assert post.status_code == 201, post.text
    assert post.json()["body"] == "Any good phone deals today?"


@pytest.mark.asyncio
async def test_duplicate_message_blocked_with_progressive_penalty(client: AsyncClient):
    slug = await _seed_marketplace()
    headers = await _user_headers(client)
    await client.post(f"/marketplaces/{slug}/community/join", headers=headers)
    channels = await client.get(f"/marketplaces/{slug}/community/channels", headers=headers)
    channel_id = channels.json()[0]["id"]

    first = await client.post(
        f"/marketplaces/community/channels/{channel_id}/messages",
        headers=headers,
        json={"body": "Is it available?", "post_type": "question"},
    )
    assert first.status_code == 201, first.text

    duplicate = await client.post(
        f"/marketplaces/community/channels/{channel_id}/messages",
        headers=headers,
        json={"body": "Is it available?", "post_type": "question"},
    )
    assert duplicate.status_code == 429, duplicate.text
    assert "already sent this message" in duplicate.json()["detail"].lower()
    assert duplicate.headers.get("retry-after")

    near_duplicate = await client.post(
        f"/marketplaces/community/channels/{channel_id}/messages",
        headers=headers,
        json={"body": "Is it  available?", "post_type": "question"},
    )
    assert near_duplicate.status_code == 429

@pytest.mark.asyncio
async def test_city_community_unchanged(client: AsyncClient):
    response = await client.get("/community/cities")
    assert response.status_code == 200
    slugs = [item["slug"] for item in response.json()]
    assert "casablanca" in slugs
