"""DriverPro-gated product and service listing video tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")


def _minimal_mp4(duration_units: int = 45000, timescale: int = 1000) -> bytes:
    mvhd_payload = (
        b"\x00"
        + b"\x00" * 3
        + b"\x00" * 8
        + timescale.to_bytes(4, "big")
        + duration_units.to_bytes(4, "big")
    )
    mvhd_atom = (8 + len(mvhd_payload)).to_bytes(4, "big") + b"mvhd" + mvhd_payload
    moov_atom = (8 + len(mvhd_atom)).to_bytes(4, "big") + b"moov" + mvhd_atom
    ftyp = (16).to_bytes(4, "big") + b"ftyp" + b"mp42" + b"\x00" * 4
    return ftyp + moov_atom + b"\x00" * 64


async def _checkout_driver_pro(client: AsyncClient, headers: dict, monkeypatch) -> None:
    monkeypatch.setattr(settings, "subscriptions_enabled", True)
    monkeypatch.setattr(settings, "payments_enabled", True)
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    res = await client.post(
        "/billing/checkout/subscription/seller_pro",
        headers=headers,
        json={},
    )
    assert res.status_code == 201, res.text


async def _upload_validated_video(client: AsyncClient, headers: dict) -> str:
    mp4 = _minimal_mp4()
    presign = await client.post(
        "/uploads/presign",
        headers=headers,
        json={"filename": "listing.mp4", "content_type": "video/mp4", "purpose": "video"},
    )
    assert presign.status_code == 200, presign.text
    body = presign.json()

    put = await client.put(
        body["upload_url"],
        headers={
            "Content-Type": "video/mp4",
            "x-ms-blob-type": "BlockBlob",
            "Authorization": headers["Authorization"],
        },
        content=mp4,
    )
    assert put.status_code == 201, put.text

    validate = await client.post(
        "/uploads/validate-video",
        headers=headers,
        json={
            "public_url": body["public_url"],
            "content_type": "video/mp4",
            "duration_seconds": 45,
        },
    )
    assert validate.status_code == 200, validate.text
    return body["public_url"]


@pytest.mark.asyncio
async def test_free_seller_cannot_presign_video(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    monkeypatch.setattr(settings, "rewarded_ads_enabled", False)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(
            client,
            email=f"presign-free-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        await create_test_seller(client, headers, **seller_create_payload())

        blocked = await client.post(
            "/uploads/presign",
            headers=headers,
            json={"filename": "clip.mp4", "content_type": "video/mp4", "purpose": "video"},
        )
        assert blocked.status_code == 403
        assert "DriverPro" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_free_seller_cannot_attach_product_video(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    monkeypatch.setattr(settings, "rewarded_ads_enabled", False)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(
            client,
            email=f"product-video-free-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())

        blocked = await client.post(
            f"/sellers/{shop['id']}/products",
            headers=headers,
            json={
                "name": "Video product",
                "description": "Test",
                "price_mad": 25,
                "video_url": "https://example.com/video.mp4",
            },
        )
        assert blocked.status_code == 403
        assert "DriverPro" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_free_seller_cannot_attach_service_video(monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)
    monkeypatch.setattr(settings, "rewarded_ads_enabled", False)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        user = await register_test_user(
            client,
            email=f"service-video-free-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())

        blocked = await client.post(
            f"/sellers/{shop['id']}/services",
            headers=headers,
            json={
                "name": "Video service",
                "description": "Test",
                "price_mad": 25,
                "video_url": "https://example.com/video.mp4",
            },
        )
        assert blocked.status_code == 403
        assert "DriverPro" in blocked.json()["detail"]


@pytest.mark.asyncio
async def test_driver_pro_can_attach_product_and_service_video(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        user = await register_test_user(
            client,
            email=f"listing-video-pro-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        headers = {"Authorization": f"Bearer {user['access_token']}"}
        shop = await create_test_seller(client, headers, **seller_create_payload())
        await _checkout_driver_pro(client, headers, monkeypatch)

        from app.services.storage_provider import reset_storage_provider_cache

        monkeypatch.setattr(settings, "storage_provider", "local")
        monkeypatch.setattr(settings, "storage_backend", "local")
        monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
        monkeypatch.setattr(settings, "public_api_url", "http://testserver")
        reset_storage_provider_cache()

        video_url = await _upload_validated_video(client, headers)

        product = await client.post(
            f"/sellers/{shop['id']}/products",
            headers=headers,
            json={
                "name": "Pro product",
                "description": "With video",
                "price_mad": 99,
                "video_url": video_url,
            },
        )
        assert product.status_code == 201, product.text
        assert product.json()["video_url"]

        service = await client.post(
            f"/sellers/{shop['id']}/services",
            headers=headers,
            json={
                "name": "Pro service",
                "description": "With video",
                "price_mad": 149,
                "video_url": video_url,
            },
        )
        assert service.status_code == 201, service.text
        assert service.json()["video_url"]

        public_product = await client.get(f"/products/{product.json()['id']}")
        assert public_product.status_code == 200
        assert public_product.json()["product"]["video_url"]

        public_service = await client.get(f"/services/{service.json()['id']}")
        assert public_service.status_code == 200
        assert public_service.json()["service"]["video_url"]


@pytest.mark.asyncio
async def test_seller_cannot_attach_video_to_other_sellers_listing(monkeypatch, tmp_path):
    monkeypatch.setattr(settings, "payment_provider", "manual")
    monkeypatch.setattr(settings, "allow_manual_billing", True)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        owner = await register_test_user(
            client,
            email=f"owner-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        owner_headers = {"Authorization": f"Bearer {owner['access_token']}"}
        owner_shop = await create_test_seller(client, owner_headers, **seller_create_payload())

        intruder = await register_test_user(
            client,
            email=f"intruder-{uuid4().hex[:8]}@example.com",
            account_type="seller",
        )
        intruder_headers = {"Authorization": f"Bearer {intruder['access_token']}"}
        await create_test_seller(client, intruder_headers, **seller_create_payload())
        await _checkout_driver_pro(client, intruder_headers, monkeypatch)

        from app.services.storage_provider import reset_storage_provider_cache

        monkeypatch.setattr(settings, "storage_provider", "local")
        monkeypatch.setattr(settings, "storage_backend", "local")
        monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
        monkeypatch.setattr(settings, "public_api_url", "http://testserver")
        reset_storage_provider_cache()

        intruder_video = await _upload_validated_video(client, intruder_headers)

        product = await client.post(
            f"/sellers/{owner_shop['id']}/products",
            headers=intruder_headers,
            json={
                "name": "Hijack",
                "description": "Blocked",
                "price_mad": 10,
                "video_url": intruder_video,
            },
        )
        assert product.status_code == 404
