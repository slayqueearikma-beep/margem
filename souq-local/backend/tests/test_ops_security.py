"""Admin IP guard and readiness checks."""

from uuid import uuid4

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
async def test_admin_origin_guard_blocks_missing_origin_in_strict_env(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "app_env", "staging")
    monkeypatch.setattr(settings, "cors_origins", ["https://admin.example.com"])
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/admin/users",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_admin_origin_guard_allows_missing_origin_from_allowlisted_ip(
    client: AsyncClient, monkeypatch
):
    monkeypatch.setattr(settings, "app_env", "staging")
    monkeypatch.setattr(settings, "cors_origins", ["https://admin.example.com"])
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/admin/users",
        headers={"X-Forwarded-For": "192.168.11.101"},
    )
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_admin_origin_guard_allows_trusted_origin(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "cors_origins", ["https://admin.example.com"])
    res = await client.get(
        "/admin/users",
        headers={"Origin": "https://admin.example.com"},
    )
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_admin_origin_passes_through_to_staff_auth_for_non_admin(
    client: AsyncClient, monkeypatch
):
    from tests.auth_helpers import register_test_user

    monkeypatch.setattr(settings, "cors_origins", ["https://admin.example.com"])
    user = await register_test_user(client, email=f"buyer-admin-{uuid4().hex[:8]}@example.com")
    headers = {"Authorization": f"Bearer {user['access_token']}"}
    res = await client.get(
        "/admin/users",
        headers={
            **headers,
            "Origin": "https://admin.example.com",
        },
    )
    assert res.status_code == 403
    assert res.json()["detail"] == "Staff access required"


@pytest.mark.asyncio
async def test_metrics_rejects_foreign_ip_without_allowlist(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", [])
    res = await client.get("/metrics", headers={"X-Forwarded-For": "8.8.8.8"})
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_metrics_allows_loopback_without_allowlist(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", [])
    res = await client.get("/metrics")
    assert res.status_code == 200
    assert "dribex_uptime_seconds" in res.text


@pytest.mark.asyncio
async def test_metrics_allows_admin_allowlisted_ip(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    res = await client.get("/metrics", headers={"X-Forwarded-For": "192.168.11.101, 10.0.0.1"})
    assert res.status_code == 200


@pytest.mark.asyncio
async def test_health_and_ready_unaffected_by_metrics_guard(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "admin_ip_allowlist", [])
    health = await client.get("/health")
    ready = await client.get("/ready")
    assert health.status_code == 200
    assert ready.status_code == 200


@pytest.mark.asyncio
async def test_client_ip_ignores_spoofed_xff_when_proxy_hops_zero(monkeypatch):
    from starlette.requests import Request

    from app.services.client_ip import get_client_ip

    monkeypatch.setattr(settings, "trusted_proxy_hops", 0)
    scope = {
        "type": "http",
        "headers": [(b"x-forwarded-for", b"192.168.11.101")],
        "client": ("203.0.113.5", 1234),
    }
    request = Request(scope)
    assert get_client_ip(request) == "203.0.113.5"


@pytest.mark.asyncio
async def test_client_ip_uses_xff_when_proxy_hops_configured(client: AsyncClient, monkeypatch):
    monkeypatch.setattr(settings, "trusted_proxy_hops", 1)
    monkeypatch.setattr(settings, "admin_ip_allowlist", ["192.168.0.0/16"])
    res = await client.get(
        "/admin/users",
        headers={"X-Forwarded-For": "192.168.11.101, 10.0.0.1"},
    )
    assert res.status_code == 401


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
