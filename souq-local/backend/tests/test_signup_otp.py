"""Signup OTP verification before account registration."""

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


@pytest.mark.asyncio
async def test_signup_otp_email_flow_and_register(client: AsyncClient):
    email = "otp-user@example.com"
    sent = await client.post(
        "/auth/signup/otp/send",
        json={"email": email, "phone": "+212600000001", "channel": "email"},
    )
    assert sent.status_code == 200, sent.text
    payload = sent.json()
    assert payload["channel"] == "email"
    assert "@" in payload["destination_masked"]
    code = payload["dev_code"]
    assert code and len(code) == 6

    verified = await client.post(
        "/auth/signup/otp/verify",
        json={"email": email, "code": code, "channel": "email"},
    )
    assert verified.status_code == 200, verified.text
    proof = verified.json()["signup_proof"]
    assert len(proof) >= 20

    body = await register_test_user(
        client,
        email=email,
        account_type="buyer",
        display_name="OTP User",
        channel="email",
    )
    assert body["access_token"]


@pytest.mark.asyncio
async def test_signup_otp_rejects_wrong_code(client: AsyncClient):
    email = "otp-wrong@example.com"
    sent = await client.post(
        "/auth/signup/otp/send",
        json={"email": email, "phone": "", "channel": "email"},
    )
    assert sent.status_code == 200, sent.text

    verified = await client.post(
        "/auth/signup/otp/verify",
        json={"email": email, "code": "000000", "channel": "email"},
    )
    assert verified.status_code == 400


@pytest.mark.asyncio
async def test_register_requires_signup_proof(client: AsyncClient):
    response = await client.post(
        "/auth/register",
        json={
            "email": "no-proof@example.com",
            "password": "SecurePass1",
            "account_type": "buyer",
            "display_name": "No Proof",
        },
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_signup_otp_blocks_existing_email(client: AsyncClient):
    email = "existing-otp@example.com"
    await register_test_user(client, email=email, account_type="buyer")

    sent = await client.post(
        "/auth/signup/otp/send",
        json={"email": email, "phone": "", "channel": "email"},
    )
    assert sent.status_code == 409
    assert sent.json()["detail"] == "Email already registered"
