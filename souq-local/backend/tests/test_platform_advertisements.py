"""Simple platform advertisement system tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.config import settings
from app.main import app
from app.models import PlatformAdvertisement, UserRole
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")

SAMPLE_AD = {
    "title": "Summer sale",
    "image_url": "https://cdn.example.com/ads/summer.jpg",
    "target_url": "https://example.com/promo",
    "is_active": True,
}


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


async def _admin_headers(client: AsyncClient) -> dict[str, str]:
    email = f"admin-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    import app.database as database
    from app.models import User

    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.ADMIN
        await session.commit()
    return {"Authorization": f"Bearer {body['access_token']}"}


async def _create_ad(client: AsyncClient, headers: dict[str, str], **overrides) -> dict:
    payload = {**SAMPLE_AD, **overrides}
    res = await client.post("/admin/advertisements", headers=headers, json=payload)
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.asyncio
async def test_anonymous_user_sees_active_ads():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        public = await client.get("/ads/active")
        assert public.status_code == 200
        ids = {row["id"] for row in public.json()}
        assert created["id"] in ids


@pytest.mark.asyncio
async def test_inactive_advertisement_not_displayed():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, is_active=False)
        public = await client.get("/ads/active")
        assert public.status_code == 200
        assert all(row["id"] != created["id"] for row in public.json())


@pytest.mark.asyncio
async def test_free_buyer_sees_ads():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_headers = await _admin_headers(client)
        await _create_ad(client, admin_headers)
        buyer = await register_test_user(client, email=f"buyer-ads-{uuid4().hex[:8]}@example.com")
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        res = await client.get("/ads/active", headers=buyer_headers)
        assert res.status_code == 200
        assert len(res.json()) >= 1


@pytest.mark.asyncio
async def test_plus_buyer_ads_hidden(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_headers = await _admin_headers(client)
        await _create_ad(client, admin_headers)
        buyer = await register_test_user(client, email=f"plus-ads-{uuid4().hex[:8]}@example.com")
        buyer_headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        checkout = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=buyer_headers,
            json={},
        )
        assert checkout.status_code == 201, checkout.text
        res = await client.get("/ads/active", headers=buyer_headers)
        assert res.status_code == 200
        assert res.json() == []


@pytest.mark.asyncio
async def test_free_seller_sees_ads():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_headers = await _admin_headers(client)
        await _create_ad(client, admin_headers)
        seller = await register_test_user(
            client,
            email=f"seller-ads-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        await create_test_seller(client, seller_headers, **seller_create_payload())
        res = await client.get("/ads/active", headers=seller_headers)
        assert res.status_code == 200
        assert len(res.json()) >= 1


@pytest.mark.asyncio
async def test_driver_pro_seller_ads_hidden(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_headers = await _admin_headers(client)
        await _create_ad(client, admin_headers)
        seller = await register_test_user(
            client,
            email=f"driver-ads-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        seller_headers = {"Authorization": f"Bearer {seller['access_token']}"}
        await create_test_seller(client, seller_headers, **seller_create_payload())
        checkout = await client.post(
            "/billing/checkout/subscription/seller_pro",
            headers=seller_headers,
            json={},
        )
        assert checkout.status_code == 201, checkout.text
        res = await client.get("/ads/active", headers=seller_headers)
        assert res.status_code == 200
        assert res.json() == []


@pytest.mark.asyncio
async def test_non_admin_cannot_manage_advertisements():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        buyer = await register_test_user(client, email=f"not-admin-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        blocked = await client.post("/admin/advertisements", headers=headers, json=SAMPLE_AD)
        assert blocked.status_code == 403


@pytest.mark.asyncio
async def test_admin_rejects_unsafe_target_url():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        res = await client.post(
            "/admin/advertisements",
            headers=headers,
            json={
                **SAMPLE_AD,
                "target_url": "javascript:alert(1)",
            },
        )
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_admin_sanitizes_title_html():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, title="<b>Safe</b> title")
        assert created["title"] == "Safe title"
        import app.database as database

        async with database.SessionLocal() as session:
            row = await session.get(PlatformAdvertisement, created["id"])
            assert row is not None
            assert row.title == "Safe title"
