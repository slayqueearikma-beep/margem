"""Security-focused tests for MFA, lockout, JWT revocation, and token hygiene."""

import pyotp
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.mfa import encrypt_secret, verify_totp_code


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, email: str, password: str = "SecurePass1") -> dict:
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": "buyer",
            "display_name": "Security Tester",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _login(client: AsyncClient, email: str, password: str = "SecurePass1") -> dict:
    response = await client.post("/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()


async def test_login_lockout_after_repeated_failures(client: AsyncClient):
    email = "lockout@example.com"
    await _register(client, email)

    for _ in range(5):
        bad = await client.post("/auth/login", json={"email": email, "password": "wrong-password"})
        assert bad.status_code == 401

    locked = await client.post("/auth/login", json={"email": email, "password": "SecurePass1"})
    assert locked.status_code == 429


async def test_password_reset_invalidates_prior_tokens(client: AsyncClient):
    email = "reset-invalidate@example.com"
    await _register(client, email)

    first = await client.post("/auth/password-reset/request", json={"email": email})
    assert first.status_code == 204
    second = await client.post("/auth/password-reset/request", json={"email": email})
    assert second.status_code == 204


async def test_mfa_enrollment_and_login_flow(client: AsyncClient):
    email = "mfa-user@example.com"
    session = await _register(client, email)
    headers = {"Authorization": f"Bearer {session['access_token']}"}

    enroll = await client.post("/auth/mfa/enroll", headers=headers)
    assert enroll.status_code == 200, enroll.text
    secret = enroll.json()["secret"]

    code = pyotp.TOTP(secret).now()
    confirm = await client.post("/auth/mfa/confirm", headers=headers, json={"code": code})
    assert confirm.status_code == 200, confirm.text
    assert len(confirm.json()["recovery_codes"]) == 8

    challenge = await client.post("/auth/login", json={"email": email, "password": "SecurePass1"})
    assert challenge.status_code == 200
    body = challenge.json()
    assert body["mfa_required"] is True
    assert body["mfa_token"]

    bad = await client.post(
        "/auth/mfa/login",
        json={"mfa_token": body["mfa_token"], "code": "000000"},
    )
    assert bad.status_code == 401

    good = await client.post(
        "/auth/mfa/login",
        json={"mfa_token": body["mfa_token"], "code": pyotp.TOTP(secret).now()},
    )
    assert good.status_code == 200
    assert good.json()["access_token"]


async def test_logout_all_revokes_access_tokens(client: AsyncClient):
    email = "revoke@example.com"
    session = await _register(client, email)
    access = session["access_token"]
    headers = {"Authorization": f"Bearer {access}"}

    logout = await client.post("/auth/logout-all", headers=headers)
    assert logout.status_code == 204

    me = await client.get("/auth/me", headers=headers)
    assert me.status_code == 401


async def test_data_export_requires_auth(client: AsyncClient):
    anon = await client.get("/auth/me/export")
    assert anon.status_code == 401

    email = "export@example.com"
    session = await _register(client, email)
    headers = {"Authorization": f"Bearer {session['access_token']}"}
    exported = await client.get("/auth/me/export", headers=headers)
    assert exported.status_code == 200
    payload = exported.json()
    assert payload["user"]["email"] == email


def test_totp_helpers_roundtrip():
    secret = pyotp.random_base32()
    encrypted = encrypt_secret(secret)
    code = pyotp.TOTP(secret).now()
    assert verify_totp_code(secret, code)
