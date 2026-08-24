"""Phase 1 compliance tests — PATCH /auth/me, subscription cancel, reports, erasure."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import User, UserRole
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _staff_headers(client: AsyncClient) -> dict:
    email = f"staff-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email, account_type="buyer", display_name="Staff")
    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.SUPPORT
        await session.commit()
    return {"Authorization": f"Bearer {body['access_token']}"}


@pytest.mark.asyncio
async def test_patch_auth_me_allowed_fields(client: AsyncClient):
    body = await register_test_user(client, email=f"patch-me-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    res = await client.patch(
        "/auth/me",
        headers=headers,
        json={"display_name": "Updated Name", "phone": "+212600000000"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["display_name"] == "Updated Name"
    assert data["phone"] == "+212600000000"


@pytest.mark.asyncio
async def test_patch_auth_me_rejects_forbidden_fields(client: AsyncClient):
    body = await register_test_user(client, email=f"patch-deny-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    res = await client.patch(
        "/auth/me",
        headers=headers,
        json={"role": "admin", "is_premium": True},
    )
    assert res.status_code == 400


@pytest.mark.asyncio
async def test_subscription_cancel_at_period_end(client: AsyncClient, monkeypatch):
    from app.config import settings

    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    body = await register_test_user(client, email=f"cancel-sub-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    plans = await client.get("/subscriptions/plans")
    plan_code = plans.json()[0]["code"]
    checkout = await client.post(
        f"/subscriptions/checkout/{plan_code}",
        headers=headers,
        json={"subscription_terms_accepted": True, "acceptance_language": "en"},
    )
    assert checkout.status_code in {200, 201}

    cancel1 = await client.post("/billing/subscriptions/me/cancel", headers=headers)
    assert cancel1.status_code == 204
    cancel2 = await client.post("/billing/subscriptions/me/cancel", headers=headers)
    assert cancel2.status_code == 204

    me = await client.get("/subscriptions/me", headers=headers)
    assert me.status_code == 200
    sub = me.json()
    assert sub["cancel_at_period_end"] is True
    assert sub["cancelled_at"] is not None


@pytest.mark.asyncio
async def test_discovery_report_admin_workflow(client: AsyncClient):
    reporter_body = await register_test_user(client, email=f"reporter-{uuid4().hex[:8]}@example.com")
    reporter_headers = {"Authorization": f"Bearer {reporter_body['access_token']}"}
    staff_headers = await _staff_headers(client)
    seller_body = await register_test_user(client, email=f"seller-{uuid4().hex[:8]}@example.com")
    seller_headers = {"Authorization": f"Bearer {seller_body['access_token']}"}
    seller = await client.post(
        "/sellers",
        headers=seller_headers,
        json={
            "business_name": "Report Test Shop",
            "description": "Test",
            "address": "1 Test St",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.59,
            "phone": "+212600000099",
            "whatsapp_number": "+212600000099",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
            "seller_terms_acknowledged": True,
            "acceptance_language": "en",
        },
    )
    assert seller.status_code == 201, seller.text
    seller_id = seller.json()["id"]

    created = await client.post(
        "/reports",
        headers=reporter_headers,
        json={"seller_id": seller_id, "reason": "spam", "details": "test report"},
    )
    assert created.status_code == 201
    report_id = created.json()["id"]

    listed = await client.get("/admin/discovery/reports", headers=staff_headers)
    assert listed.status_code == 200
    assert any(row["id"] == report_id for row in listed.json())

    updated = await client.patch(
        f"/admin/discovery/reports/{report_id}",
        headers=staff_headers,
        json={"status": "resolved", "resolution_notes": "Reviewed"},
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "resolved"


@pytest.mark.asyncio
async def test_erasure_request_duplicate_safe(client: AsyncClient):
    body = await register_test_user(client, email=f"erase-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    first = await client.post(
        "/privacy/requests",
        headers=headers,
        json={"request_type": "erasure", "details": "Please erase my account"},
    )
    second = await client.post(
        "/privacy/requests",
        headers=headers,
        json={"request_type": "erasure", "details": "Duplicate attempt"},
    )
    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]
