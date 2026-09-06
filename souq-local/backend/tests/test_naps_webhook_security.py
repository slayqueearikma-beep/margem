"""NAPS webhook security regression tests."""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.config import settings
from app.main import app
from app.models import DribexServicePayment, PaymentWebhookEvent, PlatformPaymentStatus, SubscriptionPlan
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


def _sign_payload(payload: bytes, secret: str) -> str:
    return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()


@pytest.fixture
def naps_settings(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "naps")
    monkeypatch.setattr(settings, "naps_merchant_id", "test-merchant")
    monkeypatch.setattr(settings, "naps_secret_key", "test-secret-key-32chars-minimum!!")
    monkeypatch.setattr(settings, "naps_webhook_secret", "webhook-secret-key-32chars-min!!")
    monkeypatch.setattr(settings, "naps_epay_payment_init_url", "https://example.test/naps/init")
    reset_payment_provider_cache()


@pytest.mark.asyncio
async def test_webhook_accepts_valid_signature(client: AsyncClient, naps_settings):
    payload = json.dumps({"event_id": "evt-valid-1", "status": "pending"}).encode()
    signature = _sign_payload(payload, settings.naps_webhook_secret)
    res = await client.post(
        "/billing/webhooks/naps",
        content=payload,
        headers={settings.naps_webhook_signature_header: signature},
    )
    assert res.status_code == 204


@pytest.mark.asyncio
async def test_webhook_rejects_invalid_signature(client: AsyncClient, naps_settings):
    payload = json.dumps({"event_id": "evt-invalid-1", "status": "success"}).encode()
    res = await client.post(
        "/billing/webhooks/naps",
        content=payload,
        headers={settings.naps_webhook_signature_header: "deadbeef"},
    )
    assert res.status_code == 400


@pytest.mark.asyncio
async def test_webhook_duplicate_event_is_idempotent(client: AsyncClient, naps_settings):
    payload = json.dumps({"event_id": "evt-dup-naps-1", "status": "pending"}).encode()
    signature = _sign_payload(payload, settings.naps_webhook_secret)
    headers = {settings.naps_webhook_signature_header: signature}

    first = await client.post("/billing/webhooks/naps", content=payload, headers=headers)
    second = await client.post("/billing/webhooks/naps", content=payload, headers=headers)
    assert first.status_code == 204
    assert second.status_code == 204

    async with database.SessionLocal() as session:
        rows = (
            await session.execute(
                select(PaymentWebhookEvent).where(PaymentWebhookEvent.event_id == "evt-dup-naps-1")
            )
        ).scalars().all()
        assert len(rows) == 1


@pytest.mark.asyncio
async def test_webhook_concurrent_duplicate_does_not_return_500(naps_settings, monkeypatch):
    transport = ASGITransport(app=app)
    user = None
    async with AsyncClient(transport=transport, base_url="http://test") as setup_client:
        user = await register_test_user(setup_client, email=f"wh-race-{uuid4().hex[:8]}@example.com")

    payment_id = None
    plan_price = None
    async with database.SessionLocal() as session:
        plan = (
            await session.execute(
                select(SubscriptionPlan).where(SubscriptionPlan.code == "buyer_premium")
            )
        ).scalar_one()
        plan_price = float(plan.price_mad)
        payment = DribexServicePayment(
            id=uuid4(),
            user_id=user["user"]["id"],
            seller_id=None,
            service_type="subscription",
            service_code=plan.code,
            amount_mad=plan_price,
            currency="mad",
            status=PlatformPaymentStatus.PENDING,
            provider="naps",
        )
        session.add(payment)
        await session.commit()
        payment_id = payment.id

    payload = json.dumps(
        {
            "event_id": "evt-concurrent-race-1",
            "status": "success",
            "payment_id": "naps-ref-1",
            "amount": plan_price,
            "dribex_payment_id": str(payment_id),
        }
    ).encode()
    signature = _sign_payload(payload, settings.naps_webhook_secret)
    headers = {settings.naps_webhook_signature_header: signature}

    async def _post_once() -> int:
        async with AsyncClient(transport=transport, base_url="http://test") as race_client:
            res = await race_client.post("/billing/webhooks/naps", content=payload, headers=headers)
            return res.status_code

    statuses = await asyncio.gather(_post_once(), _post_once())
    assert 500 not in statuses
    assert all(code in {204, 404} for code in statuses)
    assert statuses.count(204) >= 1


@pytest.mark.asyncio
async def test_webhook_rate_limit_applies_to_invalid_signatures(naps_settings):
    from limits import parse

    from app.limiter import limiter

    route_limit = limiter._route_limits["app.routers.billing.payment_webhook"][0]
    original = route_limit.limit
    route_limit.limit = parse("2/minute")
    limiter.reset()

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            payload = b"{}"
            for _ in range(2):
                res = await client.post(
                    "/billing/webhooks/naps",
                    content=payload,
                    headers={settings.naps_webhook_signature_header: "deadbeef"},
                )
                assert res.status_code == 400

            limited = await client.post(
                "/billing/webhooks/naps",
                content=payload,
                headers={settings.naps_webhook_signature_header: "deadbeef"},
            )
            assert limited.status_code == 429
    finally:
        route_limit.limit = original
        limiter.reset()


def test_webhook_is_not_globally_rate_limit_exempt():
    from app.limiter import limiter

    assert "app.routers.billing.payment_webhook" in limiter._route_limits
