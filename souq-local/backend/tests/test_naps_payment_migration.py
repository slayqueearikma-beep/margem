"""NAPS payment migration tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


@pytest.mark.asyncio
async def test_no_stripe_runtime_provider():
    from app.services import payment_provider as provider_module

    source = open(provider_module.__file__, encoding="utf-8").read()
    assert "stripe" not in source.lower()
    assert "StripePaymentProvider" not in source


@pytest.mark.asyncio
async def test_manual_dev_subscription_payment():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"naps-dev-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        checkout = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=headers,
            json={},
        )
        assert checkout.status_code == 201, checkout.text
        body = checkout.json()
        assert body["provider"] == "manual"
        assert body["status"] == "success"

        payment_id = body["payment_id"]
        status_res = await client.get(f"/billing/payments/{payment_id}", headers=headers)
        assert status_res.status_code == 200
        assert status_res.json()["status"] == "success"


@pytest.mark.asyncio
async def test_naps_production_requires_configuration(monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "payment_provider", "naps")
    monkeypatch.setattr(settings, "naps_merchant_id", "")
    reset_payment_provider_cache()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(client, email=f"naps-prod-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        checkout = await client.post(
            "/billing/checkout/subscription/buyer_premium",
            headers=headers,
            json={},
        )
        assert checkout.status_code == 503


@pytest.mark.asyncio
async def test_webhook_rejects_missing_signature(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "naps")
    monkeypatch.setattr(settings, "naps_merchant_id", "test-merchant")
    monkeypatch.setattr(settings, "naps_secret_key", "test-secret-key-32chars-minimum!!")
    monkeypatch.setattr(settings, "naps_webhook_secret", "webhook-secret-key-32chars-min!!")
    monkeypatch.setattr(settings, "naps_epay_payment_init_url", "https://example.test/naps/init")
    reset_payment_provider_cache()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post("/billing/webhooks/naps", content=b"{}")
        assert res.status_code == 400


@pytest.mark.asyncio
async def test_frontend_price_manipulation_rejected():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        packages = await client.get("/billing/advertising/packages")
        assert packages.status_code == 200
        pkg = packages.json()[0]
        assert pkg["price_mad"] > 0


def test_repository_has_zero_stripe_imports():
    from pathlib import Path

    app_dir = Path(__file__).resolve().parents[1] / "app"
    forbidden = ("import stripe", "from stripe", "StripePaymentProvider", "stripe_billing")
    hits: list[str] = []
    for path in app_dir.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        for token in forbidden:
            if token in text:
                hits.append(f"{path}:{token}")
    assert not hits, "\n".join(hits)
