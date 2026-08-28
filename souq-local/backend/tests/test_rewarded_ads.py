"""Rewarded advertisement grant and security tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.auth_helpers import register_verified_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
def launch_monetization(monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "payments_enabled", False)
    monkeypatch.setattr(settings, "subscriptions_enabled", False)
    monkeypatch.setattr(settings, "payment_provider", "none")
    monkeypatch.setattr(settings, "ads_enabled", True)
    monkeypatch.setattr(settings, "rewarded_ads_enabled", True)


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_backend_starts_without_naps_credentials():
    from pydantic import ValidationError
    from app.config import Settings

    Settings(
        _env_file=None,
        app_env="production",
        debug=False,
        auth_dev_bypass=False,
        admin_require_staff_mfa=True,
        jwt_secret_key="ci-production-secret-key-32chars-minxx",
        upload_token_secret="ci-upload-token-secret-key-32chars-min",
        mfa_encryption_key="ci-mfa-encryption-key-32chars-minimum",
        rewarded_ad_signing_secret="ci-rewarded-ad-signing-secret-32chars",
        cors_origins=["https://dribex.ma"],
        allowed_hosts=["api.dribex.ma"],
        storage_provider="selfhosted",
        minio_endpoint="http://minio:9000",
        minio_access_key="minio-access",
        minio_secret_key="minio-secret-key-32chars-minimum",
        brevo_api_key="ci-brevo-api-key-32chars-minimumxx",
        brevo_sender_email="noreply@dribex.ma",
        brevo_sender_name="Dribex",
        public_app_url="https://dribex.ma",
        public_api_url="https://api.dribex.ma",
        admin_ip_allowlist=["203.0.113.0/24"],
        payments_enabled=False,
        subscriptions_enabled=False,
        ads_enabled=True,
        rewarded_ads_enabled=True,
        payment_provider="none",
    )


@pytest.mark.asyncio
async def test_reward_session_and_complete_unlocks_video(client: AsyncClient, launch_monetization):
    user = await register_verified_user(client, account_type="provider")
    headers = user["headers"]

    from tests.seller_helpers import create_test_seller, seller_create_payload

    seller = await create_test_seller(client, headers, **seller_create_payload())
    assert seller["id"]

    entitlements = await client.get("/subscriptions/entitlements", headers=headers)
    assert entitlements.status_code == 200
    body = entitlements.json()
    assert body["seller"]["video_uploads_enabled"] is False
    assert body["payments_enabled"] is False
    assert body["subscriptions_enabled"] is False
    assert body["rewarded_ads_enabled"] is True

    session_res = await client.post(
        "/rewards/sessions",
        headers=headers,
        json={"feature_code": "video_upload"},
    )
    assert session_res.status_code == 201, session_res.text
    session_body = session_res.json()

    complete_res = await client.post(
        "/rewards/complete",
        headers=headers,
        json={
            "session_id": session_body["session_id"],
            "session_token": session_body["session_token"],
            "provider": "internal",
        },
    )
    assert complete_res.status_code == 200, complete_res.text

    entitlements_after = await client.get("/subscriptions/entitlements", headers=headers)
    assert entitlements_after.json()["seller"]["video_uploads_enabled"] is True


@pytest.mark.asyncio
async def test_reward_complete_rejects_invalid_token(client: AsyncClient):
    user = await register_verified_user(client, account_type="customer")
    headers = user["headers"]

    session_res = await client.post(
        "/rewards/sessions",
        headers=headers,
        json={"feature_code": "saved_search"},
    )
    assert session_res.status_code == 201
    session_body = session_res.json()

    bad = await client.post(
        "/rewards/complete",
        headers=headers,
        json={
            "session_id": session_body["session_id"],
            "session_token": "deadbeef" * 4,
            "provider": "internal",
        },
    )
    assert bad.status_code == 403


@pytest.mark.asyncio
async def test_reward_complete_is_idempotent_per_session(client: AsyncClient):
    user = await register_verified_user(client, account_type="customer")
    headers = user["headers"]

    session_res = await client.post(
        "/rewards/sessions",
        headers=headers,
        json={"feature_code": "saved_search"},
    )
    session_body = session_res.json()

    first = await client.post(
        "/rewards/complete",
        headers=headers,
        json={
            "session_id": session_body["session_id"],
            "session_token": session_body["session_token"],
            "provider": "internal",
        },
    )
    assert first.status_code == 200

    second = await client.post(
        "/rewards/complete",
        headers=headers,
        json={
            "session_id": session_body["session_id"],
            "session_token": session_body["session_token"],
            "provider": "internal",
        },
    )
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_saved_search_unlocks_with_rewarded_ad(client: AsyncClient, launch_monetization):
    user = await register_verified_user(client, account_type="customer")
    headers = user["headers"]

    blocked = await client.post(
        "/saved-searches",
        headers=headers,
        json={"query": "shoes", "city": "Casablanca", "category": "fashion"},
    )
    assert blocked.status_code == 403

    session_res = await client.post(
        "/rewards/sessions",
        headers=headers,
        json={"feature_code": "saved_search"},
    )
    assert session_res.status_code == 201
    session_body = session_res.json()
    complete_res = await client.post(
        "/rewards/complete",
        headers=headers,
        json={
            "session_id": session_body["session_id"],
            "session_token": session_body["session_token"],
            "provider": "internal",
        },
    )
    assert complete_res.status_code == 200

    allowed = await client.post(
        "/saved-searches",
        headers=headers,
        json={"query": "shoes", "city": "Casablanca", "category": "fashion"},
    )
    assert allowed.status_code == 201, allowed.text


@pytest.mark.asyncio
async def test_billing_checkout_disabled_when_payments_off(client: AsyncClient, launch_monetization):
    user = await register_verified_user(client, account_type="customer")
    checkout = await client.post(
        "/billing/checkout/subscription/buyer_premium",
        headers=user["headers"],
        json={},
    )
    assert checkout.status_code == 503
