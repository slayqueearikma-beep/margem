"""Privacy compliance API tests (Morocco Law 09-08 user rights)."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _auth_headers(client: AsyncClient) -> dict:
    email = f"privacy-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    return {"Authorization": f"Bearer {body['access_token']}"}


@pytest.mark.asyncio
async def test_marketing_consent_sync_records_evidence(client: AsyncClient):
    headers = await _auth_headers(client)

    update = await client.put(
        "/privacy/consents/marketing_email",
        headers=headers,
        json={"granted": True, "language": "fr"},
    )
    assert update.status_code == 200
    assert update.json()["granted"] is True
    assert update.json()["legal_basis"] == "consent"

    state = await client.get("/privacy/consents", headers=headers)
    assert state.status_code == 200
    marketing = next(item for item in state.json() if item["consent_type"] == "marketing_email")
    assert marketing["granted"] is True

    history = await client.get("/privacy/consents/history", headers=headers)
    assert history.status_code == 200
    assert history.json()[0]["consent_type"] == "marketing_email"
    assert history.json()[0]["policy_version"] == "2.0.0"


@pytest.mark.asyncio
async def test_access_privacy_request_auto_completes(client: AsyncClient):
    headers = await _auth_headers(client)

    created = await client.post(
        "/privacy/requests",
        headers=headers,
        json={"request_type": "access", "details": "Please provide my data"},
    )
    assert created.status_code == 201
    body = created.json()
    assert body["request_type"] == "access"
    assert body["status"] == "completed"
    assert "export" in body["resolution_notes"].lower()


@pytest.mark.asyncio
async def test_marketing_opposition_request_withdraws_consent(client: AsyncClient):
    headers = await _auth_headers(client)

    await client.put(
        "/privacy/consents/marketing_email",
        headers=headers,
        json={"granted": True, "language": "en"},
    )
    opposition = await client.post(
        "/privacy/requests",
        headers=headers,
        json={"request_type": "opposition", "details": "Stop marketing emails"},
    )
    assert opposition.status_code == 201
    assert opposition.json()["status"] == "completed"

    state = await client.get("/privacy/consents", headers=headers)
    marketing = next(item for item in state.json() if item["consent_type"] == "marketing_email")
    assert marketing["granted"] is False


@pytest.mark.asyncio
async def test_data_export_includes_consents_and_requests(client: AsyncClient):
    headers = await _auth_headers(client)

    await client.put(
        "/privacy/consents/marketing_email",
        headers=headers,
        json={"granted": False, "language": "en"},
    )
    await client.post(
        "/privacy/requests",
        headers=headers,
        json={"request_type": "access", "details": "Export test"},
    )

    export = await client.get("/auth/me/export", headers=headers)
    assert export.status_code == 200
    payload = export.json()
    assert payload["export_format"] == "dribex-json-v1"
    assert "consents" in payload
    assert "privacy_requests" in payload
    assert "messages_sent" in payload
    assert "legal_acceptances" in payload


@pytest.mark.asyncio
async def test_privacy_endpoints_exempt_from_legal_gate(client: AsyncClient):
    email = f"gate-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email, accept_policies=False)
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    blocked = await client.get("/favorites", headers=headers)
    assert blocked.status_code == 403

    allowed = await client.get("/privacy/consents", headers=headers)
    assert allowed.status_code == 200
