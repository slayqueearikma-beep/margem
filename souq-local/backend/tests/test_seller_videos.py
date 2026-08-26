import pytest
from httpx import ASGITransport, AsyncClient

from app.config import settings
from app.main import app
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str) -> dict:
    return await register_test_user(
        client,
        email=email,
        account_type="seller",
        display_name="Video Seller",
    )


async def _create_seller(client: AsyncClient, token: str) -> dict:
    response = await client.post(
        "/sellers",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "business_name": "Video Shop",
            "description": "Desc",
            "address": "1 Main Street",
            "city": "Casablanca",
            "latitude": 33.5,
            "longitude": -7.6,
            "phone": "+212600000000",
            "cover_image_url": "",
            "logo_image_url": "",
            "opening_hours": {
                "days": {
                    "Mon": True,
                    "Tue": True,
                    "Wed": True,
                    "Thu": True,
                    "Fri": True,
                    "Sat": True,
                    "Sun": False,
                },
                "open": "09:00",
                "close": "21:00",
                "marketplace_slug": "other-casablanca-markets",
                "seller_terms_acknowledged": True,
                "acceptance_language": "en",
            },
            "category_ids": [],
            "custom_marketplace_name": "Test Market",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


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


@pytest.mark.asyncio
async def test_add_video_rejects_unvalidated_media_for_free_seller():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "video-free@example.com")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token)

        response = await client.post(
            f"/sellers/{created['id']}/videos",
            headers=headers,
            json={
                "video_url": "http://example.com/video.mp4",
                "duration_seconds": 30,
                "content_type": "video/mp4",
            },
        )
        assert response.status_code == 400, response.text


@pytest.mark.asyncio
async def test_add_video_rejects_duration_60_seconds():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "video-long@example.com")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token)

        from app.database import SessionLocal
        from app.models import SellerProfile, User
        from sqlalchemy import select

        async with SessionLocal() as session:
            result = await session.execute(select(User).where(User.email == "video-long@example.com"))
            user = result.scalar_one()
            seller = (
                await session.execute(
                    select(SellerProfile).where(SellerProfile.user_id == user.id)
                )
            ).scalar_one()
            seller.is_premium = True
            await session.commit()

        response = await client.post(
            f"/sellers/{created['id']}/videos",
            headers=headers,
            json={
                "video_url": "http://example.com/video.mp4",
                "duration_seconds": 60,
                "content_type": "video/mp4",
            },
        )
        assert response.status_code == 422, response.text


@pytest.mark.asyncio
async def test_local_video_upload_and_publish(tmp_path, monkeypatch):
    from app.services.storage_provider import reset_storage_provider_cache

    monkeypatch.setattr(settings, "storage_provider", "local")
    monkeypatch.setattr(settings, "storage_backend", "local")
    monkeypatch.setattr(settings, "local_media_root", str(tmp_path))
    monkeypatch.setattr(settings, "public_api_url", "http://testserver")
    reset_storage_provider_cache()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        seller = await _register(client, "video-premium@example.com")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token)

        from app.database import SessionLocal
        from app.models import SellerProfile, User
        from sqlalchemy import select

        async with SessionLocal() as session:
            result = await session.execute(select(User).where(User.email == "video-premium@example.com"))
            user = result.scalar_one()
            seller = (
                await session.execute(
                    select(SellerProfile).where(SellerProfile.user_id == user.id)
                )
            ).scalar_one()
            seller.is_premium = True
            await session.commit()

        mp4 = _minimal_mp4()
        presign = await client.post(
            "/uploads/presign",
            headers=headers,
            json={"filename": "clip.mp4", "content_type": "video/mp4", "purpose": "video"},
        )
        assert presign.status_code == 200, presign.text
        body = presign.json()

        put = await client.put(
            body["upload_url"],
            headers={
                "Content-Type": "video/mp4",
                "x-ms-blob-type": "BlockBlob",
                "Authorization": f"Bearer {token}",
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

        publish = await client.post(
            f"/sellers/{created['id']}/videos",
            headers=headers,
            json={
                "video_url": body["public_url"],
                "duration_seconds": 45,
                "content_type": "video/mp4",
                "title": "Shop tour",
            },
        )
        assert publish.status_code == 201, publish.text
        payload = publish.json()
        assert payload["duration_seconds"] == pytest.approx(45.0)
        assert payload["title"] == "Shop tour"
