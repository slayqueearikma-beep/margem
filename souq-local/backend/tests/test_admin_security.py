"""Admin web security middleware tests."""

import pytest
from httpx import ASGITransport, AsyncClient


@pytest.mark.asyncio
async def test_admin_api_rejects_unknown_origin(prepare_database, monkeypatch):
    from app.config import settings
    from app.main import app

    monkeypatch.setattr(settings, "cors_origins", ["http://192.168.1.10:8080"])

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get(
            "/admin/users",
            headers={
                "Origin": "http://evil.example.com",
                "Authorization": "Bearer invalid",
            },
        )
        assert res.status_code == 403
        assert res.json()["detail"] == "Admin API access denied for this origin"


@pytest.mark.asyncio
async def test_admin_api_allows_configured_origin(prepare_database, monkeypatch):
    from app.config import settings
    from app.main import app

    monkeypatch.setattr(settings, "cors_origins", ["http://192.168.1.10:8080"])

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get(
            "/admin/users",
            headers={
                "Origin": "http://192.168.1.10:8080",
                "Authorization": "Bearer invalid",
            },
        )
        # Origin allowed; auth still fails with 401.
        assert res.status_code == 401
