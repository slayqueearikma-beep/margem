"""Legal policy acceptance enforcement on auth routes."""

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


async def _register_without_acceptance(client: AsyncClient) -> dict:
    email = f"legal-gate-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(
        client,
        email=email,
        password="SecurePass1",
        account_type="buyer",
        display_name="Gate User",
        accept_policies=False,
    )
    return {"headers": {"Authorization": f"Bearer {body['access_token']}"}}


async def test_export_blocked_until_legal_acceptance(client: AsyncClient):
    auth = await _register_without_acceptance(client)

    blocked = await client.get("/auth/me/export", headers=auth["headers"])
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "legal_acceptance_required"

    allowed = await client.get("/auth/me", headers=auth["headers"])
    assert allowed.status_code == 200
