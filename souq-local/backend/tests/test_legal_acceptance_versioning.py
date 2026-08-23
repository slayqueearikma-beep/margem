"""Legal acceptance must track policy versions, not a one-time boolean."""

from datetime import UTC, datetime
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import LegalAcceptance, User
from app.services.legal_acceptance import get_pending_policy_ids
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient) -> tuple[dict, str]:
    email = f"legal-ver-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(
        client,
        email=email,
        password="SecurePass1",
        account_type="buyer",
        display_name="Version User",
        accept_policies=False,
    )
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    return headers, body["user"]["id"]


@pytest.mark.asyncio
async def test_outdated_policy_version_requires_reacceptance(client: AsyncClient):
    headers, user_id = await _register(client)

    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.id == user_id))).scalar_one()
        session.add_all(
            [
                LegalAcceptance(
                    user_id=user.id,
                    policy_id="terms_of_service",
                    policy_version="1.0.0",
                    language="en",
                    accepted_at=datetime.now(UTC),
                ),
                LegalAcceptance(
                    user_id=user.id,
                    policy_id="privacy_policy",
                    policy_version="1.0.0",
                    language="en",
                    accepted_at=datetime.now(UTC),
                ),
            ]
        )
        await session.commit()

    me = await client.get("/auth/me", headers=headers)
    assert me.status_code == 200
    body = me.json()
    assert body["legal_acceptance_complete"] is False
    assert set(body["pending_legal_policies"]) == {"terms_of_service", "privacy_policy"}

    blocked = await client.get("/favorites", headers=headers)
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "legal_acceptance_required"


@pytest.mark.asyncio
async def test_acceptance_records_current_manifest_versions(client: AsyncClient):
    headers, _user_id = await _register(client)

    accept = await client.post(
        "/legal/accept",
        headers=headers,
        json={
            "policies": [
                {"policy_id": "terms_of_service"},
                {"policy_id": "privacy_policy"},
            ],
            "language": "fr",
            "acknowledged": True,
        },
    )
    assert accept.status_code == 200
    payload = accept.json()
    versions = {item["policy_id"]: item["policy_version"] for item in payload["accepted"]}
    assert versions["terms_of_service"] == "2.0.0"
    assert versions["privacy_policy"] == "2.0.0"

    async with database.SessionLocal() as session:
        pending = await get_pending_policy_ids(session, user_id=_user_id)
        assert pending == []
