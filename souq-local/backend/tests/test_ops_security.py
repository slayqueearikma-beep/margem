"""Admin IP guard and readiness checks."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_ready_includes_media_check_local(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "storage_backend", "local")
    res = await client.get("/ready")
    assert res.status_code == 200
    body = res.json()
    assert body["database"] == "ok"
    assert body.get("media") == "ok"
    assert body.get("schema") == "ok"


@pytest.mark.asyncio
async def test_admin_ip_guard_blocks_foreign_ip(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/admin/users",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert res.status_code == 403

@pytest.mark.asyncio
async def test_admin_ip_guard_allows_private_ip(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/admin/users",
        headers={"X-Forwarded-For": "192.168.11.101"},
    )
    # Still 401 without auth, but not blocked by IP guard.
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_admin_ip_guard_blocks_community_admin_from_foreign_ip(
    client: AsyncClient, monkeypatch
):
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/community/admin/cities",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_admin_origin_guard_blocks_unlisted_origin(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "cors_origins", ["https://admin.example.com"])
    res = await client.get(
        "/admin/users",
        headers={
            "Origin": "https://evil.example.com",
            "X-Forwarded-For": "127.0.0.1",
        },
    )
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_production_validation_errors_are_sanitized(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "debug", False)
    res = await client.post("/auth/login", json={"email": "not-an-email", "password": ""})
    assert res.status_code == 422
    body = res.json()
    assert body["detail"] == "Validation error"
    assert "request_id" in body
    assert "errors" not in body
