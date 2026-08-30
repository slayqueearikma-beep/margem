"""Shared seller creation payloads for backend integration tests."""

from __future__ import annotations

from httpx import AsyncClient

# Seeded in tests/conftest.py prepare_database fixture.
DEFAULT_TEST_MARKETPLACE_SLUG = "other-casablanca-markets"


def seller_create_payload(**overrides: object) -> dict:
    """Minimal valid seller registration payload for test fixtures."""
    payload = {
        "business_name": "Test Shop",
        "description": "Test storefront",
        "address": "1 Main Street",
        "city": "Casablanca",
        "latitude": 33.57,
        "longitude": -7.59,
        "phone": "+212600000010",
        "marketplace_slug": DEFAULT_TEST_MARKETPLACE_SLUG,
        "seller_terms_acknowledged": True,
        "acceptance_language": "en",
    }
    payload.update(overrides)
    return payload


async def create_test_seller(
    client: AsyncClient,
    headers: dict[str, str],
    **overrides: object,
) -> dict:
    response = await client.post(
        "/sellers",
        headers=headers,
        json=seller_create_payload(**overrides),
    )
    assert response.status_code == 201, response.text
    return response.json()
