"""Legal policy acceptance API tests."""

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


async def _register(client: AsyncClient) -> dict:
    email = f"legal-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(
        client,
        email=email,
        password="SecurePass1",
        account_type="buyer",
        display_name="Legal User",
        accept_policies=False,
    )
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
    }


async def test_new_user_requires_legal_acceptance(client: AsyncClient):
    auth = await _register(client)

    me = await client.get("/auth/me", headers=auth["headers"])
    assert me.status_code == 200
    body = me.json()
    assert body["legal_acceptance_complete"] is False
    assert set(body["pending_legal_policies"]) == {"terms_of_service", "privacy_policy"}

    status = await client.get("/legal/accept/status", headers=auth["headers"])
    assert status.status_code == 200
    assert status.json()["complete"] is False
    assert set(status.json()["pending"]) == {"terms_of_service", "privacy_policy"}


async def test_protected_endpoint_blocked_until_acceptance(client: AsyncClient):
    auth = await _register(client)

    blocked = await client.get("/favorites", headers=auth["headers"])
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "legal_acceptance_required"


async def test_accept_policies_records_versions(client: AsyncClient):
    auth = await _register(client)

    accept = await client.post(
        "/legal/accept",
        headers=auth["headers"],
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
    payload = accept.json()
    assert payload["complete"] is True
    assert payload["pending"] == []
    assert len(payload["accepted"]) == 2
    assert all(item["policy_version"] for item in payload["accepted"])

    me = await client.get("/auth/me", headers=auth["headers"])
    assert me.json()["legal_acceptance_complete"] is True

    allowed = await client.get("/favorites", headers=auth["headers"])
    assert allowed.status_code == 200


async def test_duplicate_acceptance_is_idempotent(client: AsyncClient):
    auth = await _register(client)
    body = {
        "policies": [
            {"policy_id": "terms_of_service"},
            {"policy_id": "privacy_policy"},
        ],
        "language": "fr",
        "acknowledged": True,
    }
    first = await client.post("/legal/accept", headers=auth["headers"], json=body)
    second = await client.post("/legal/accept", headers=auth["headers"], json=body)
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["complete"] is True


async def test_accept_requires_acknowledgement(client: AsyncClient):
    auth = await _register(client)
    response = await client.post(
        "/legal/accept",
        headers=auth["headers"],
        json={
            "policies": [
                {"policy_id": "terms_of_service"},
                {"policy_id": "privacy_policy"},
            ],
            "language": "en",
            "acknowledged": False,
        },
    )
    assert response.status_code == 422
