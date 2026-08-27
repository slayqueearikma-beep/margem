"""Dribex Plus+ / DriverPro entitlement and subscription security tests."""

import asyncio
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.config import settings
from app.main import app
from app.models import Product, Service, Subscription, SubscriptionPlan, SubscriptionStatus, User
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


async def _checkout_plan(client: AsyncClient, headers: dict, plan_code: str) -> None:
    res = await client.post(
        f"/billing/checkout/subscription/{plan_code}",
        headers=headers,
        json={},
    )
    assert res.status_code == 201, res.text


@pytest.mark.asyncio
async def test_plan_prices_and_names():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        plans = await client.get("/subscriptions/plans")
        assert plans.status_code == 200
        by_code = {row["code"]: row for row in plans.json()}
        assert by_code["buyer_premium"]["name"] == "Dribex Plus+"
        assert float(by_code["buyer_premium"]["price_mad"]) == 50
        assert by_code["seller_pro"]["name"] == "DriverPro"
        assert float(by_code["seller_pro"]["price_mad"]) == 149


@pytest.mark.asyncio
async def test_free_buyer_has_no_plus_entitlement(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"free-buyer-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        ent = await client.get("/subscriptions/entitlements", headers=headers)
        assert ent.status_code == 200
        body = ent.json()
        assert body["buyer"]["plus_plus_active"] is False
        assert body["buyer"]["show_plus_badge"] is False
        assert body["buyer"]["promotional_ads_suppressed"] is False


@pytest.mark.asyncio
async def test_active_plus_buyer_entitlements(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"plus-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await _checkout_plan(client, headers, "buyer_premium")
        me = await client.get("/auth/me", headers=headers)
        assert me.status_code == 200
        assert me.json()["plus_plus_active"] is True
        assert me.json()["show_plus_badge"] is True
        assert me.json()["promotional_ads_suppressed"] is True


@pytest.mark.asyncio
async def test_plus_does_not_grant_driver_pro(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"dual-{uuid4().hex[:8]}@example.com"
        user = await register_test_user(client, email=email, account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())
        await _checkout_plan(client, headers, "buyer_premium")
        ent = await client.get("/subscriptions/entitlements", headers=headers)
        assert ent.json()["buyer"]["plus_plus_active"] is True
        assert ent.json()["seller"]["driver_pro_active"] is False
        assert ent.json()["seller"]["video_uploads_enabled"] is False
        assert ent.json()["seller"]["promotional_ads_suppressed"] is False
        assert ent.json()["seller"]["ads_enabled"] is True


@pytest.mark.asyncio
async def test_free_seller_has_promotional_ads_enabled(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"free-seller-ads-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())
        ent = await client.get("/subscriptions/entitlements", headers=headers)
        assert ent.status_code == 200
        body = ent.json()
        assert body["seller"]["driver_pro_active"] is False
        assert body["seller"]["promotional_ads_suppressed"] is False
        assert body["seller"]["ads_enabled"] is True
        assert body["promotional_ads_suppressed"] is False
        assert body["ads_enabled"] is True
        me = await client.get("/auth/me", headers=headers)
        assert me.json()["promotional_ads_suppressed"] is False
        assert me.json()["ads_enabled"] is True


@pytest.mark.asyncio
async def test_driver_pro_suppresses_promotional_ads_for_seller(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"driver-ads-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())
        await _checkout_plan(client, headers, "seller_pro")
        ent = await client.get("/subscriptions/entitlements", headers=headers)
        assert ent.status_code == 200
        body = ent.json()
        assert body["seller"]["driver_pro_active"] is True
        assert body["seller"]["promotional_ads_suppressed"] is True
        assert body["seller"]["ads_enabled"] is False
        assert body["promotional_ads_suppressed"] is True
        assert body["ads_enabled"] is False
        me = await client.get("/auth/me", headers=headers)
        assert me.json()["promotional_ads_suppressed"] is True
        assert me.json()["ads_enabled"] is False
        assert me.json()["show_plus_badge"] is False


@pytest.mark.asyncio
async def test_free_seller_combined_listing_limit(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"seller-limit-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        seller_id = shop["id"]
        for idx in range(5):
            res = await client.post(
                f"/sellers/{seller_id}/products",
                headers=headers,
                json={"name": f"Item {idx}", "description": "Test", "price_mad": 10},
            )
            assert res.status_code == 201, res.text
        blocked = await client.post(
            f"/sellers/{seller_id}/services",
            headers=headers,
            json={"name": "Extra", "description": "Blocked", "price_mad": 20},
        )
        assert blocked.status_code == 403
        assert "DriverPro" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_free_seller_cannot_upload_videos(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"video-free-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        blocked = await client.post(
            f"/sellers/{shop['id']}/videos",
            headers=headers,
            json={"video_url": "https://example.com/video.mp4", "duration_seconds": 10},
        )
        assert blocked.status_code == 403
        assert "DriverPro" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_driver_pro_allows_twenty_combined_items(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"driver-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        await _checkout_plan(client, headers, "seller_pro")
        seller_id = shop["id"]
        for idx in range(20):
            endpoint = "products" if idx % 2 == 0 else "services"
            res = await client.post(
                f"/sellers/{seller_id}/{endpoint}",
                headers=headers,
                json={"name": f"Item {idx}", "description": "Test", "price_mad": 10},
            )
            assert res.status_code == 201, res.text
        blocked = await client.post(
            f"/sellers/{seller_id}/products",
            headers=headers,
            json={"name": "Too many", "description": "Blocked", "price_mad": 10},
        )
        assert blocked.status_code == 403


@pytest.mark.asyncio
async def test_driver_pro_requires_seller_profile(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"buyer-only-{uuid4().hex[:8]}@example.com", account_type="buyer")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        blocked = await client.post(
            "/billing/checkout/subscription/seller_pro",
            headers=headers,
            json={},
        )
        assert blocked.status_code == 400
        assert "seller profile" in blocked.json()["detail"].lower()


@pytest.mark.asyncio
async def test_both_subscriptions_can_coexist(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"both-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())
        await _checkout_plan(client, headers, "buyer_premium")
        await _checkout_plan(client, headers, "seller_pro")
        ent = await client.get("/subscriptions/entitlements", headers=headers)
        body = ent.json()
        assert body["buyer"]["plus_plus_active"] is True
        assert body["seller"]["driver_pro_active"] is True


@pytest.mark.asyncio
async def test_expired_driver_pro_blocks_new_items_but_keeps_existing(monkeypatch):
    import app.database as database

    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = f"expired-driver-{uuid4().hex[:8]}@example.com"
        user = await register_test_user(client, email=email, account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        seller_id = shop["id"]
        await _checkout_plan(client, headers, "seller_pro")
        for idx in range(8):
            await client.post(
                f"/sellers/{seller_id}/products",
                headers=headers,
                json={"name": f"Keep {idx}", "description": "Test", "price_mad": 10},
            )
        async with database.SessionLocal() as session:
            db_user = (await session.execute(select(User).where(User.email == email))).scalar_one()
            plan = (
                await session.execute(select(SubscriptionPlan).where(SubscriptionPlan.code == "seller_pro"))
            ).scalar_one()
            sub = (
                await session.execute(
                    select(Subscription).where(
                        Subscription.user_id == db_user.id,
                        Subscription.plan_id == plan.id,
                    )
                )
            ).scalar_one()
            sub.current_period_end = datetime.now(UTC) - timedelta(days=1)
            sub.status = SubscriptionStatus.EXPIRED
            db_user.is_premium = False
            shop_row = (
                await session.execute(select(Product).where(Product.seller_id == seller_id))
            ).scalars().all()
            assert len(shop_row) == 8
            await session.commit()

        blocked = await client.post(
            f"/sellers/{seller_id}/products",
            headers=headers,
            json={"name": "New blocked", "description": "Test", "price_mad": 10},
        )
        assert blocked.status_code == 403


@pytest.mark.asyncio
async def test_concurrent_creation_cannot_exceed_free_limit(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"race-{uuid4().hex[:8]}@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        seller_id = shop["id"]
        for idx in range(4):
            res = await client.post(
                f"/sellers/{seller_id}/products",
                headers=headers,
                json={"name": f"Item {idx}", "description": "Test", "price_mad": 10},
            )
            assert res.status_code == 201, res.text

        async def create_one(name: str):
            return await client.post(
                f"/sellers/{seller_id}/products",
                headers=headers,
                json={"name": name, "description": "Race", "price_mad": 10},
            )

        results = await asyncio.gather(create_one("A"), create_one("B"))
        statuses = sorted(res.status_code for res in results)
        assert statuses == [201, 403]

        async with AsyncClient(transport=transport, base_url="http://test") as verify_client:
            verify_client.headers.update(headers)
            ent = await verify_client.get("/subscriptions/entitlements")
            assert ent.json()["seller"]["combined_listing_count"] == 5
