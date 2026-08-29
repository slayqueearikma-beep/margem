"""Buyer premium gates and subscription maintenance."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.config import settings
from app.main import app
from app.models import Subscription, SubscriptionPlan, SubscriptionStatus, User
from app.services.payment_provider import reset_payment_provider_cache
from app.services.subscription_maintenance import run_subscription_maintenance
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


@pytest.mark.asyncio
async def test_saved_search_requires_buyer_premium(monkeypatch):
    monkeypatch.setattr(settings, "subscriptions_enabled", True)
    monkeypatch.setattr(settings, "payments_enabled", True)
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"buyer-gate-{uuid4().hex[:8]}@example.com"
        body = await register_test_user(client, email=email, account_type="buyer")
        headers = {"Authorization": f"Bearer {body['access_token']}"}

        blocked = await client.post(
            "/saved-searches",
            headers=headers,
            json={"query": "shoes", "city": "Casablanca", "category": "fashion"},
        )
        assert blocked.status_code == 403

        checkout = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=headers,
            json={},
        )
        assert checkout.status_code == 201, checkout.text

        allowed = await client.post(
            "/saved-searches",
            headers=headers,
            json={"query": "shoes", "city": "Casablanca", "category": "fashion"},
        )
        assert allowed.status_code == 201, allowed.text


@pytest.mark.asyncio
async def test_seller_pro_does_not_unlock_saved_searches(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"seller-gate-{uuid4().hex[:8]}@example.com"
        body = await register_test_user(client, email=email, account_type="seller")
        headers = {"Authorization": f"Bearer {body['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())

        checkout = await client.post(
            "/billing/checkout/subscription/seller_pro",
            headers=headers,
            json={},
        )
        assert checkout.status_code == 201, checkout.text

        blocked = await client.post(
            "/saved-searches",
            headers=headers,
            json={"query": "tools", "city": "Casablanca", "category": "services"},
        )
        assert blocked.status_code == 403



@pytest.mark.asyncio
async def test_subscription_maintenance_revokes_expired_subscriptions():
    import app.database as database

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"expired-{uuid4().hex[:8]}@example.com"
        await register_test_user(client, email=email, account_type="buyer")

        async with database.SessionLocal() as session:
            db_user = (await session.execute(select(User).where(User.email == email))).scalar_one()
            plan = (
                await session.execute(
                    select(SubscriptionPlan).where(SubscriptionPlan.code == "buyer_premium")
                )
            ).scalar_one()
            now = datetime.now(UTC)
            sub = Subscription(
                id=uuid4(),
                user_id=db_user.id,
                plan_id=plan.id,
                status=SubscriptionStatus.ACTIVE,
                provider="manual",
                provider_reference=f"test-{uuid4().hex[:8]}",
                current_period_start=now - timedelta(days=40),
                current_period_end=now - timedelta(days=1),
            )
            session.add(sub)
            db_user.is_premium = True
            db_user.premium_until = sub.current_period_end
            await session.commit()

            touched = await run_subscription_maintenance(session)
            assert touched >= 1

            await session.refresh(db_user)
            await session.refresh(sub)
            assert db_user.is_premium is False
            assert sub.status == SubscriptionStatus.EXPIRED
