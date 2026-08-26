"""Geospatial search ranking tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.geo import haversine_km
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _create_seller(
    client: AsyncClient,
    *,
    name: str,
    latitude: float,
    longitude: float,
) -> dict:
    seller = await register_test_user(
        client,
        email=f"{name.lower().replace(' ', '-')}-{uuid4().hex[:6]}@example.com",
        account_type="seller",
        display_name=name,
    )
    profile = await client.post(
        "/sellers",
        headers={"Authorization": f"Bearer {seller['access_token']}"},
        json={
            "business_name": name,
            "description": f"{name} storefront",
            "address": "1 Test Street",
            "city": "Casablanca",
            "latitude": latitude,
            "longitude": longitude,
            "phone": "+212600000001",
            "whatsapp_number": "+212600000001",
            "payment_methods": ["cash"],
            "delivery_methods": ["pickup"],
            "marketplace_slug": "other-casablanca-markets",
            "seller_terms_acknowledged": True,
            "acceptance_language": "en"
        },
    )
    assert profile.status_code == 201, profile.text
    return profile.json()


@pytest.mark.asyncio
async def test_search_sorts_sellers_by_distance(client: AsyncClient):
    origin_lat, origin_lng = 33.5731, -7.5898
    near = await _create_seller(
        client,
        name="Near Shop",
        latitude=origin_lat + 0.01,
        longitude=origin_lng + 0.01,
    )
    far = await _create_seller(
        client,
        name="Far Shop",
        latitude=origin_lat + 0.2,
        longitude=origin_lng + 0.2,
    )

    response = await client.get(
        "/search",
        params={
            "q": "Shop",
            "mode": "sellers",
            "city": "Casablanca",
            "lat": origin_lat,
            "lng": origin_lng,
            "sort": "distance",
            "limit": 10,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["sellers"]) == 2
    assert body["sellers"][0]["id"] == near["id"]
    assert body["sellers"][1]["id"] == far["id"]
    assert body["sellers"][0]["distance_km"] < body["sellers"][1]["distance_km"]


def test_haversine_km_same_point_is_zero():
    assert haversine_km(33.57, -7.59, 33.57, -7.59) < 0.001


@pytest.mark.asyncio
async def test_search_distance_sort_requires_coordinates(client: AsyncClient):
    response = await client.get(
        "/search",
        params={"q": "shop", "mode": "sellers", "sort": "distance"},
    )
    assert response.status_code == 422
