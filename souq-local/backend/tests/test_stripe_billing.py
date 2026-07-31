"""Stripe billing tests (mocked — no live Stripe API calls)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models import SubscriptionPlan, User

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register_seller(client: AsyncClient) -> dict:
    email = f"seller-{uuid4().hex[:8]}@example.com"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "seller",
            "display_name": "Stripe Seller",
        },
    )
    assert res.status_code == 201, res.text
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    profile = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": "Stripe Test Shop",
            "description": "Billing test",
            "address": "1 Test St",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.59,
            "phone": "+212600000001",
            "whatsapp_number": "+212600000001",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert profile.status_code == 201, profile.text
    return {"email": email, "headers": headers}


@pytest.mark.asyncio
async def test_billing_config_disabled_by_default(client: AsyncClient):
    res = await client.get("/billing/config")
    assert res.status_code == 200
    body = res.json()
    assert body["stripe_enabled"] is False


@pytest.mark.asyncio
async def test_checkout_requires_stripe_config(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post(
        "/billing/checkout",
        headers=seller["headers"],
        json={"plan_code": "premium", "interval": "monthly"},
    )
    assert res.status_code == 503


@pytest.mark.asyncio
async def test_list_plans_returns_business_tiers(client: AsyncClient):
    res = await client.get("/subscriptions/plans")
    assert res.status_code == 200
    codes = {plan["code"] for plan in res.json()}
    assert codes == {"vip", "premium", "enterprise"}
    premium = next(p for p in res.json() if p["code"] == "premium")
    assert premium["price_mad_yearly"] == 1990
    assert premium["tier_level"] == 2


@pytest.mark.asyncio
async def test_manual_subscribe_dev_only(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post("/subscriptions/subscribe/vip", headers=seller["headers"])
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["provider"] == "manual"
    assert body["plan"]["code"] == "vip"


@pytest.mark.asyncio
async def test_webhook_rejects_missing_signature(client: AsyncClient, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "stripe_secret_key", "sk_test_mock")
    monkeypatch.setattr(settings, "stripe_webhook_secret", "whsec_mock")
    res = await client.post("/billing/webhooks/stripe", content=b"{}")
    assert res.status_code == 400


@pytest.mark.asyncio
async def test_billing_sync_requires_stripe_config(client: AsyncClient):
    seller = await _register_seller(client)
    res = await client.post("/billing/sync", headers=seller["headers"], json={})
    assert res.status_code == 503


@pytest.mark.asyncio
async def test_record_webhook_idempotency():
    import app.database as database
    from app.services.stripe_billing import record_webhook_event

    async with database.SessionLocal() as session:
        first = await record_webhook_event(session, "evt_test_1", "checkout.session.completed")
        second = await record_webhook_event(session, "evt_test_1", "checkout.session.completed")
        await session.commit()
    assert first is True
    assert second is False
