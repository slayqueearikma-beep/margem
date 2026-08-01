"""Seller category validation tests."""

from __future__ import annotations

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.factories import sample_category_ids, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")



async def _register_seller(client: AsyncClient) -> dict:
    email = f"seller-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "seller",
            "display_name": "Category Seller",
        },
    )
    assert res.status_code == 201, res.text
    return {"headers": {"Authorization": f"Bearer {res.json()['access_token']}"}}


@pytest.mark.asyncio
async def test_create_seller_requires_at_least_one_category(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post(
        "/sellers",
        headers=seller["headers"],
        json=seller_create_payload(category_ids=[]),
    )
    assert res.status_code == 422


@pytest.mark.asyncio
async def test_create_seller_accepts_up_to_three_categories(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post(
        "/sellers",
        headers=seller["headers"],
        json=seller_create_payload(
            business_name="Multi Category Shop",
            category_ids=sample_category_ids(3),
        ),
    )
    assert res.status_code == 201, res.text
    body = res.json()
    assert len(body["categories"]) == 3


@pytest.mark.asyncio
async def test_create_seller_rejects_more_than_three_categories(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post(
        "/sellers",
        headers=seller["headers"],
        json=seller_create_payload(category_ids=sample_category_ids(4)),
    )
    assert res.status_code == 422
