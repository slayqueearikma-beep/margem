"""Regression tests for the comprehensive security audit hardening pass."""

from io import BytesIO
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image

from app.config import settings
from app.main import app
from app.services.geo import validate_morocco_coordinates
from app.services.url_security import reject_private_or_internal_url
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client(tmp_path, monkeypatch):
    from app.services.storage_provider import reset_storage_provider_cache

    monkeypatch.setattr(settings, "storage_provider", "local")
    monkeypatch.setattr(settings, "storage_backend", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://test")
    reset_storage_provider_cache()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


def _jpeg_bytes() -> bytes:
    img = Image.new("RGB", (200, 200), color=(120, 80, 40))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


async def _create_seller(client: AsyncClient, token: str) -> dict:
    response = await client.post(
        "/sellers",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "business_name": "Secure Shop",
            "description": "Desc",
            "address": "1 Main Street",
            "city": "Casablanca",
            "latitude": 33.5,
            "longitude": -7.6,
            "phone": "+212600000000",
            "cover_image_url": "",
            "logo_image_url": "",
            "opening_hours": {
                "days": {"Mon": True},
                "open": "09:00",
                "close": "21:00",
                "seller_terms_acknowledged": True,
                "acceptance_language": "en",
            },
            "category_ids": [],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_product_rejects_unvalidated_media_url(client: AsyncClient):
    seller = await register_test_user(client, email=f"prod-{uuid4().hex[:8]}@example.com", account_type="seller")
    shop = await _create_seller(client, seller["access_token"])
    headers = {"Authorization": f"Bearer {seller['access_token']}"}

    presign = await client.post(
        "/uploads/presign",
        headers=headers,
        json={"filename": "item.jpg", "content_type": "image/jpeg"},
    )
    assert presign.status_code == 200, presign.text
    public_url = presign.json()["public_url"]

    blocked = await client.post(
        f"/sellers/{shop['id']}/products",
        headers=headers,
        json={"name": "Widget", "description": "Test", "price_mad": 10, "image_url": public_url},
    )
    assert blocked.status_code == 400
    assert "validated" in blocked.json()["detail"].lower()


@pytest.mark.asyncio
async def test_product_accepts_validated_media_url(client: AsyncClient):
    seller = await register_test_user(client, email=f"prod2-{uuid4().hex[:8]}@example.com", account_type="seller")
    shop = await _create_seller(client, seller["access_token"])
    headers = {"Authorization": f"Bearer {seller['access_token']}"}

    presign = await client.post(
        "/uploads/presign",
        headers=headers,
        json={"filename": "item.jpg", "content_type": "image/jpeg"},
    )
    upload_url = presign.json()["upload_url"]
    public_url = presign.json()["public_url"]

    put = await client.put(
        upload_url,
        headers={**headers, "Content-Type": "image/jpeg"},
        content=_jpeg_bytes(),
    )
    assert put.status_code == 201, put.text

    created = await client.post(
        f"/sellers/{shop['id']}/products",
        headers=headers,
        json={"name": "Widget", "description": "Test", "price_mad": 10, "image_url": public_url},
    )
    assert created.status_code == 201, created.text


def test_reject_private_website_urls():
    with pytest.raises(ValueError, match="private"):
        reject_private_or_internal_url("http://192.168.1.10/store", field_name="website_url")
    with pytest.raises(ValueError, match="private"):
        reject_private_or_internal_url("http://localhost/admin", field_name="website_url")


def test_morocco_coordinate_bounds():
    validate_morocco_coordinates(33.5, -7.6)
    with pytest.raises(ValueError):
        validate_morocco_coordinates(48.8, 2.3)


@pytest.mark.asyncio
async def test_seller_rejects_coordinates_outside_morocco(client: AsyncClient):
    seller = await register_test_user(client, email=f"geo-{uuid4().hex[:8]}@example.com", account_type="seller")
    headers = {"Authorization": f"Bearer {seller['access_token']}"}
    blocked = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": "Paris Shop",
            "description": "Desc",
            "address": "Paris",
            "city": "Paris",
            "latitude": 48.8566,
            "longitude": 2.3522,
            "phone": "+212600000000",
            "cover_image_url": "",
            "logo_image_url": "",
            "opening_hours": {
                "days": {"Mon": True},
                "open": "09:00",
                "close": "21:00",
                "seller_terms_acknowledged": True,
                "acceptance_language": "en",
            },
            "category_ids": [],
        },
    )
    assert blocked.status_code in {400, 422}


@pytest.mark.asyncio
async def test_admin_api_rejects_bad_referer(prepare_database, monkeypatch):
    monkeypatch.setattr(settings, "cors_origins", ["http://192.168.1.10:8080"])
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as admin_client:
        res = await admin_client.get(
            "/admin/users",
            headers={
                "Referer": "http://evil.example.com/admin/",
                "Authorization": "Bearer invalid",
            },
        )
        assert res.status_code == 403


@pytest.mark.asyncio
async def test_mfa_enroll_does_not_return_plaintext_secret(client: AsyncClient):
    user = await register_test_user(client, email=f"mfa-{uuid4().hex[:8]}@example.com")
    enroll = await client.post(
        "/auth/mfa/enroll",
        headers={"Authorization": f"Bearer {user['access_token']}"},
    )
    assert enroll.status_code == 200, enroll.text
    body = enroll.json()
    assert "secret" not in body
    assert body["otpauth_uri"].startswith("otpauth://")
