"""Production readiness tests."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


async def _register_buyer(client: AsyncClient, email: str = "export-test@example.com") -> dict:
    password = "SecurePass1"
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": "buyer",
            "display_name": "Export Test",
        },
    )
    assert response.status_code == 201
    body = response.json()
    return {
        "email": email,
        "password": password,
        "access_token": body["access_token"],
    }


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_change_password_enforces_strength() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client, "pwd-test@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        response = await client.post(
            "/auth/me/password",
            json={"current_password": user["password"], "new_password": "weak"},
            headers=headers,
        )
        assert response.status_code == 400


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_data_export_requires_auth() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/auth/me/export")
        assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_data_export_returns_account() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client)
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        response = await client.get("/auth/me/export", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert "account" in body
        assert body["account"]["email"] == user["email"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_saved_search_limit_for_free_users() -> None:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await _register_buyer(client, "saved-search@example.com")
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        for i in range(3):
            response = await client.post(
                "/saved-searches",
                json={"query": f"shop {i}", "city": "Casablanca", "category": ""},
                headers=headers,
            )
            assert response.status_code == 201
        response = await client.post(
            "/saved-searches",
            json={"query": "shop overflow", "city": "Casablanca", "category": ""},
            headers=headers,
        )
        assert response.status_code == 403
