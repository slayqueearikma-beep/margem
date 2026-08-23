"""Law 53-05 electronic acceptance evidence tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import LegalAcceptance, SubscriptionAgreementRecord
from app.services.legal_acceptance import document_hash_for_policy
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_onboarding_acceptance_stores_document_hash(client: AsyncClient):
    email = f"hash-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email, accept_policies=False)
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    accept = await client.post(
        "/legal/accept",
        headers=headers,
        json={
            "policies": [
                {"policy_id": "terms_of_service"},
                {"policy_id": "privacy_policy"},
            ],
            "language": "en",
            "acknowledged": True,
        },
    )
    assert accept.status_code == 200

    expected_hash = document_hash_for_policy("terms_of_service", language="en")
    assert expected_hash

    async with database.SessionLocal() as session:
        rows = (
            await session.execute(
                select(LegalAcceptance).where(LegalAcceptance.user_id == body["user"]["id"])
            )
        ).scalars().all()
        assert len(rows) >= 2
        tos = next(r for r in rows if r.policy_id == "terms_of_service")
        assert tos.document_hash == expected_hash
        assert tos.source == "onboarding_legal_accept"
        assert tos.authentication_method == "bearer_session"


@pytest.mark.asyncio
async def test_seller_onboarding_records_seller_terms(client: AsyncClient):
    email = f"seller-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email, account_type="buyer")
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    create = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": "Test Shop",
            "description": "Quality goods",
            "address": "123 Main Street, Casablanca",
            "city": "Casablanca",
            "latitude": 33.5731,
            "longitude": -7.5898,
            "phone": "+212600000001",
            "seller_terms_acknowledged": True,
            "acceptance_language": "fr",
        },
    )
    assert create.status_code == 201, create.text

    async with database.SessionLocal() as session:
        row = (
            await session.execute(
                select(LegalAcceptance).where(
                    LegalAcceptance.user_id == body["user"]["id"],
                    LegalAcceptance.policy_id == "seller_terms",
                )
            )
        ).scalar_one()
        assert row.source == "seller_onboarding"
        assert row.document_hash


@pytest.mark.asyncio
async def test_subscription_checkout_requires_terms_acceptance(client: AsyncClient):
    email = f"sub-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    blocked = await client.post(
        "/subscriptions/checkout/buyer_premium",
        headers=headers,
        json={"subscription_terms_accepted": False},
    )
    assert blocked.status_code == 422

    ok = await client.post(
        "/subscriptions/checkout/buyer_premium",
        headers=headers,
        json={
            "subscription_terms_accepted": True,
            "acceptance_language": "en",
        },
    )
    assert ok.status_code == 200, ok.text

    async with database.SessionLocal() as session:
        agreement = (
            await session.execute(
                select(SubscriptionAgreementRecord).where(
                    SubscriptionAgreementRecord.user_id == body["user"]["id"]
                )
            )
        ).scalar_one()
        assert agreement.plan_code == "buyer_premium"
        assert agreement.document_hash


@pytest.mark.asyncio
async def test_unauthenticated_user_cannot_record_acceptance(client: AsyncClient):
    res = await client.post(
        "/legal/accept",
        json={
            "policies": [{"policy_id": "terms_of_service"}],
            "language": "en",
            "acknowledged": True,
        },
    )
    assert res.status_code == 401
