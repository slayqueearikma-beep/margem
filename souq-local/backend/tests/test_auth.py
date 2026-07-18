import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_register_requires_eight_char_password():
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
async def test_register_and_login_flow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        email = "prod-test@example.com"
        password = "securepass123"

        register = await client.post(
            "/auth/register",
            json={
                "email": email,
                "password": password,
                "account_type": "buyer",
                "display_name": "Prod Test",
            },
        )
        assert register.status_code == 201
        token = register.json()["access_token"]
        assert token

        login = await client.post(
            "/auth/login",
            json={"email": email, "password": password},
        )
        assert login.status_code == 200
        assert login.json()["access_token"]

        me = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert me.status_code == 200
        assert me.json()["email"] == email
