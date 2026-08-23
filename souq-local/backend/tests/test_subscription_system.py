"""Subscription system integration tests."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.config import settings
from app.main import app
from app.models import Subscription, SubscriptionStatus, User
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


@pytest.mark.asyncio
async def test_plans_filtered_by_audience():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller_plans = await client.get("/subscriptions/plans", params={"audience": "seller"})
        assert seller_plans.status_code == 200
        codes = {row["code"] for row in seller_plans.json()}
        assert "seller_pro" in codes
        assert "buyer_premium" not in codes

        buyer_plans = await client.get("/subscriptions/plans", params={"audience": "buyer"})
        assert buyer_plans.status_code == 200
        codes = {row["code"] for row in buyer_plans.json()}
        assert "buyer_premium" in codes
        assert "seller_pro" not in codes


@pytest.mark.asyncio
async def test_duplicate_active_subscription_checkout_rejected(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"dup-sub-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        payload = {"subscription_terms_accepted": True, "acceptance_language": "en"}

        first = await client.post(
            "/subscriptions/checkout/buyer_premium",
            headers=headers,
            json=payload,
        )
        assert first.status_code in {200, 201}, first.text

        second = await client.post(
            "/subscriptions/checkout/buyer_premium",
            headers=headers,
            json=payload,
        )
        assert second.status_code == 400
        assert "active subscription" in second.json()["detail"].lower()


@pytest.mark.asyncio
async def test_expired_subscription_not_returned_from_me():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"exp-sub-{uuid4().hex[:8]}@example.com"
        user = await register_test_user(client, email=email)
        headers = {"Authorization": f"Bearer {user['access_token']}"}

        import app.database as database
        from app.models import SubscriptionPlan

        async with database.SessionLocal() as session:
            db_user = (await session.execute(select(User).where(User.email == email))).scalar_one()
            plan = (
                await session.execute(select(SubscriptionPlan).where(SubscriptionPlan.code == "buyer_premium"))
            ).scalar_one()
            now = datetime.now(UTC)
            session.add(
                Subscription(
                    id=uuid4(),
                    user_id=db_user.id,
                    plan_id=plan.id,
                    status=SubscriptionStatus.ACTIVE,
                    current_period_start=now - timedelta(days=40),
                    current_period_end=now - timedelta(days=10),
                    provider="manual",
                    provider_reference="test-expired",
                )
            )
            db_user.is_premium = True
            db_user.premium_until = now - timedelta(days=10)
            await session.commit()

        me = await client.get("/subscriptions/me", headers=headers)
        assert me.status_code == 200
        assert me.json() is None


@pytest.mark.asyncio
async def test_cancel_subscription_requires_auth():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/billing/subscriptions/me/cancel")
        assert res.status_code == 401


@pytest.mark.asyncio
async def test_seller_pro_price_authoritative_from_backend():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/subscriptions/plans", params={"audience": "seller"})
        assert res.status_code == 200
        plan = res.json()[0]
        assert plan["code"] == "seller_pro"
        assert float(plan["price_mad"]) == 99.0
