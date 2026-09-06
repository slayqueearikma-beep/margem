"""Regression tests for backend security hardening."""

from __future__ import annotations

import json
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.config import settings
from app.main import app
from app.middleware.admin_paths import is_admin_protected_path
from app.models import DribexServicePayment, LegalAcceptance, Subscription, User
from app.services.local_storage import write_local_blob
from app.services.media_access import validate_checkout_redirect_url
from app.services.platform_billing import process_provider_webhook
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


def test_admin_paths_include_billing_admin_routes():
    assert is_admin_protected_path("/billing/admin/payments")
    assert is_admin_protected_path("/billing/admin/subscriptions")


def test_validate_checkout_redirect_rejects_foreign_host(monkeypatch):
    monkeypatch.setattr(settings, "public_app_url", "https://margem.ma")
    url = validate_checkout_redirect_url("https://evil.example/phish", default_suffix="/premium?paid=1")
    assert url == "https://margem.ma/premium?paid=1"


def test_validate_checkout_redirect_allows_app_deep_link():
    url = validate_checkout_redirect_url("margem://premium/success", default_suffix="/premium?paid=1")
    assert url == "margem://premium/success"


@pytest.mark.asyncio
async def test_private_local_media_requires_owner(client: AsyncClient, tmp_path, monkeypatch):
    from app.services.storage_provider import reset_storage_provider_cache

    monkeypatch.setattr(settings, "storage_provider", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://test")
    reset_storage_provider_cache()

    user = await register_test_user(client, email=f"media-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {user['access_token']}"}
    user_id = user["user"]["id"]
    object_key = f"private/{user_id}/secret.txt"
    write_local_blob(object_key, b"secret")

    blocked = await client.get(f"/media/{object_key}")
    assert blocked.status_code == 404

    allowed = await client.get(f"/media/{object_key}", headers=headers)
    assert allowed.status_code == 200
    assert allowed.content == b"secret"


@pytest.mark.asyncio
async def test_public_local_profile_media_is_anonymous(client: AsyncClient, tmp_path, monkeypatch):
    from app.services.storage_provider import reset_storage_provider_cache

    monkeypatch.setattr(settings, "storage_provider", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://test")
    reset_storage_provider_cache()

    object_key = f"profiles/{uuid4()}/avatar.jpg"
    write_local_blob(object_key, b"jpeg")

    res = await client.get(f"/media/{object_key}")
    assert res.status_code == 200


@pytest.mark.asyncio
async def test_account_deletion_removes_legal_acceptance_records(client: AsyncClient):
    user = await register_test_user(
        client,
        email=f"erase-{uuid4().hex[:8]}@example.com",
        password="SecurePass1",
        accept_policies=True,
    )
    headers = {"Authorization": f"Bearer {user['access_token']}"}
    user_id = user["user"]["id"]

    async with database.SessionLocal() as session:
        before = (
            await session.execute(select(LegalAcceptance).where(LegalAcceptance.user_id == user_id))
        ).scalars().all()
        assert before

    deleted = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": "SecurePass1", "confirmation": "DELETE"},
    )
    assert deleted.status_code == 204

    async with database.SessionLocal() as session:
        after = (
            await session.execute(select(LegalAcceptance).where(LegalAcceptance.user_id == user_id))
        ).scalars().all()
        assert after == []


@pytest.mark.asyncio
async def test_passwordless_account_deletion_with_confirmation_only(client: AsyncClient):
    user = await register_test_user(client, email=f"firebase-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {user['access_token']}"}

    async with database.SessionLocal() as session:
        row = await session.get(User, user["user"]["id"])
        row.password_hash = None
        await session.commit()

    deleted = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": "", "confirmation": "DELETE"},
    )
    assert deleted.status_code == 204


@pytest.mark.asyncio
async def test_duplicate_success_webhook_does_not_reactivate_subscription(monkeypatch):
    from datetime import UTC, datetime, timedelta
    from uuid import uuid4

    from app.models import PlatformPaymentStatus, SubscriptionPlan, SubscriptionStatus
    from app.services.payment_provider import VerifiedWebhook

    class _FakeProvider:
        name = "manual"

        def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook:
            data = json.loads(payload.decode())
            return VerifiedWebhook(
                event_id=data["event_id"],
                event_type=data["status"],
                provider_reference="ref-1",
                amount_mad=data.get("amount"),
                currency="mad",
                metadata={"dribex_payment_id": data["dribex_payment_id"]},
            )

    monkeypatch.setattr(
        "app.services.platform_billing.get_payment_provider",
        lambda: _FakeProvider(),
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"wh-{uuid4().hex[:8]}@example.com")

    async with database.SessionLocal() as session:
        plan = (
            await session.execute(
                select(SubscriptionPlan).where(SubscriptionPlan.code == "buyer_premium")
            )
        ).scalar_one()
        payment = DribexServicePayment(
            id=uuid4(),
            user_id=user["user"]["id"],
            seller_id=None,
            service_type="subscription",
            service_code=plan.code,
            amount_mad=float(plan.price_mad),
            currency="mad",
            status=PlatformPaymentStatus.SUCCESS,
            provider="manual",
            provider_reference="manual-sub-test",
            paid_at=datetime.now(UTC),
        )
        session.add(payment)
        await session.flush()

        from app.services.platform_billing import activate_subscription_for_payment

        db_user = await session.get(User, user["user"]["id"])
        await activate_subscription_for_payment(session, payment=payment, user=db_user, plan=plan)
        await session.commit()

        subs_before = (
            await session.execute(select(Subscription).where(Subscription.user_id == payment.user_id))
        ).scalars().all()
        assert len(subs_before) == 1
        period_end_before = subs_before[0].current_period_end

        for event_id in ("evt-dup-1", "evt-dup-2"):
            await process_provider_webhook(
                session,
                provider_name="manual",
                payload=json.dumps(
                    {
                        "event_id": event_id,
                        "status": "success",
                        "dribex_payment_id": str(payment.id),
                        "amount": float(payment.amount_mad),
                    }
                ).encode(),
                signature_header=None,
            )

        subs_after = (
            await session.execute(select(Subscription).where(Subscription.user_id == payment.user_id))
        ).scalars().all()
        assert len(subs_after) == 1
        assert subs_after[0].current_period_end == period_end_before


@pytest.mark.asyncio
async def test_billing_admin_route_honors_ip_guard(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/billing/admin/payments",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert res.status_code == 403
