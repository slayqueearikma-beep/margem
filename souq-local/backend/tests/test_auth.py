import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.services.password_policy import validate_password_strength
from tests.auth_helpers import register_test_user


def test_password_policy_requires_complexity():
    with pytest.raises(ValueError):
        validate_password_strength("password")
    validate_password_strength("SecurePass1")


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_requires_strong_password():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/auth/register",
            json={
                "email": "user@example.com",
                "password": "short",
                "account_type": "buyer",
                "display_name": "Test",
            },
        )
    assert response.status_code == 422


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_and_login_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = "prod-test@example.com"
        password = "SecurePass1"

        body = await register_test_user(
            client,
            email=email,
            password=password,
            account_type="buyer",
            display_name="Prod Test",
        )
        assert body["access_token"]
        assert body["refresh_token"]
        token = body["access_token"]

        login = await client.post(
            "/auth/login",
            json={"email": email, "password": password},
        )
        assert login.status_code == 200
        assert login.json()["refresh_token"]

        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_login_accepts_local_dev_email_format():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/auth/login",
            json={"email": "admin@margem.local", "password": "SecurePass1"},
        )
        # Validation must pass; credentials may be wrong (401), not rejected as bad email (422).
        assert response.status_code != 422, response.text
        assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_register_email_case_insensitive():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        first = await register_test_user(
            client,
            email="Case@Example.com",
            password="SecurePass1",
            account_type="buyer",
            display_name="Case User",
        )
        assert first["access_token"]

        second = await client.post(
            "/auth/signup/otp/send",
            json={
                "email": "case@example.com",
                "phone": "",
                "channel": "email",
            },
        )
        assert second.status_code == 409
