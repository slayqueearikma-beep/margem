"""Discovery-only payment architecture tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, *, email: str, account_type: str = "buyer") -> dict:
    body = await register_test_user(
        client,
        email=email,
        account_type=account_type,
        display_name="Billing User",
    )
    token = body["access_token"]
    return {"access_token": token, "headers": {"Authorization": f"Bearer {token}"}}


@pytest.mark.asyncio
async def test_marketplace_checkout_routes_absent():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        for path in ("/cart", "/checkout", "/orders", "/wishlist"):
            response = await client.get(path)
            assert response.status_code == 404, path


@pytest.mark.asyncio
async def test_dev_subscription_creates_platform_payment_record():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client, email=f"billing-{uuid4().hex[:8]}@example.com")
        headers = user["headers"]

        subscribe = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=headers,
            json={},
        )
        assert subscribe.status_code == 201, subscribe.text

        payments = await client.get("/billing/payments/me", headers=headers)
        assert payments.status_code == 200
        body = payments.json()
        assert len(body) >= 1
        assert body[0]["service_type"] == "subscription"
        assert body[0]["status"] == "success"


@pytest.mark.asyncio
async def test_advertising_packages_listed():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/billing/advertising/packages")
        assert response.status_code == 200
        codes = {row["code"] for row in response.json()}
        assert "sponsored_listing_7d" in codes


@pytest.mark.asyncio
async def test_production_blocks_manual_billing_checkout(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "payment_provider", "manual")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register(client, email=f"prod-bill-{uuid4().hex[:8]}@example.com")
        response = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=user["headers"],
            json={},
        )
        assert response.status_code == 503


def test_no_seller_payout_models_in_schema():
    from app import models

    names = {name for name in dir(models) if not name.startswith("_")}
    forbidden = {
        "SellerBalance",
        "SellerWallet",
        "SellerPayout",
        "MarketplacePayment",
        "EscrowAccount",
    }
    assert forbidden.isdisjoint(names)
