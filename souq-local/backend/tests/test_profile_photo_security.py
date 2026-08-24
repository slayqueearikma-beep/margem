"""Profile photograph security and lifecycle tests."""

from io import BytesIO
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from PIL import Image
from sqlalchemy import select

import app.database as database
from app.config import settings
from app.main import app
from app.models import User, UserMediaObject
from app.services.image_processing import sanitize_image_bytes
from app.services.local_storage import media_root, public_media_url
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


def _jpeg_bytes(width: int = 200, height: int = 200) -> bytes:
    img = Image.new("RGB", (width, height), color=(120, 80, 40))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_sanitize_strips_exif_and_reencodes():
    raw = _jpeg_bytes()
    sanitized = sanitize_image_bytes(raw, content_type="image/jpeg")
    assert sanitized.content_type == "image/jpeg"
    assert len(sanitized.data) > 0
    with Image.open(BytesIO(sanitized.data)) as img:
        assert img.getexif() == {} or len(img.getexif()) == 0


@pytest.mark.asyncio
async def test_sanitize_rejects_oversized_dimensions():
    raw = _jpeg_bytes(width=5000, height=5000)
    with pytest.raises(ValueError, match="dimensions"):
        sanitize_image_bytes(raw, content_type="image/jpeg")


@pytest.mark.asyncio
async def test_profile_photo_update_requires_owner_media_url(client: AsyncClient):
    email = f"photo-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    headers = {"Authorization": f"Bearer {body['access_token']}"}

    blocked = await client.put(
        "/auth/me/profile-photo",
        headers=headers,
        json={"profile_photo_url": "https://evil.example.com/x.jpg"},
    )
    assert blocked.status_code == 400


@pytest.mark.asyncio
async def test_profile_photo_update_and_delete(client: AsyncClient):
    email = f"photo2-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    user_id = body["user"]["id"]

    presign = await client.post(
        "/uploads/presign",
        headers=headers,
        json={"filename": "avatar.jpg", "content_type": "image/jpeg"},
    )
    assert presign.status_code == 200, presign.text
    upload_url = presign.json()["upload_url"]
    public_url = presign.json()["public_url"]

    put = await client.put(
        upload_url,
        headers={**headers, "Content-Type": "image/jpeg"},
        content=_jpeg_bytes(),
    )
    assert put.status_code == 201, put.text

    update = await client.put(
        "/auth/me/profile-photo",
        headers=headers,
        json={"profile_photo_url": public_url},
    )
    assert update.status_code == 200, update.text
    assert update.json()["profile_photo_url"] == public_url

    delete = await client.delete("/auth/me/profile-photo", headers=headers)
    assert delete.status_code == 204

    me = await client.get("/auth/me", headers=headers)
    assert me.json()["profile_photo_url"] == ""


@pytest.mark.asyncio
async def test_cannot_set_another_users_media_url(client: AsyncClient):
    user_a = await register_test_user(client, email=f"a-{uuid4().hex[:8]}@example.com")
    user_b = await register_test_user(client, email=f"b-{uuid4().hex[:8]}@example.com")
    headers_a = {"Authorization": f"Bearer {user_a['access_token']}"}
    headers_b = {"Authorization": f"Bearer {user_b['access_token']}"}

    presign = await client.post(
        "/uploads/presign",
        headers=headers_a,
        json={"filename": "mine.jpg", "content_type": "image/jpeg"},
    )
    public_url = presign.json()["public_url"]

    blocked = await client.put(
        "/auth/me/profile-photo",
        headers=headers_b,
        json={"profile_photo_url": public_url},
    )
    assert blocked.status_code == 400


@pytest.mark.asyncio
async def test_account_deletion_purges_local_media(client: AsyncClient):
    email = f"del-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    body = await register_test_user(client, email=email, password=password)
    headers = {"Authorization": f"Bearer {body['access_token']}"}
    user_id = body["user"]["id"]

    presign = await client.post(
        "/uploads/presign",
        headers=headers,
        json={"filename": "avatar.jpg", "content_type": "image/jpeg"},
    )
    public_url = presign.json()["public_url"]
    await client.put(
        presign.json()["upload_url"],
        headers={**headers, "Content-Type": "image/jpeg"},
        content=_jpeg_bytes(),
    )
    await client.put(
        "/auth/me/profile-photo",
        headers=headers,
        json={"profile_photo_url": public_url},
    )

    blob_key = public_url.split("/media/")[-1]
    path = (media_root() / blob_key).resolve()
    assert path.is_file()

    deleted = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": password, "confirmation": "DELETE"},
    )
    assert deleted.status_code == 204
    assert not path.is_file()

    async with database.SessionLocal() as session:
        rows = (
            await session.execute(
                select(UserMediaObject).where(UserMediaObject.user_id == user_id)
            )
        ).scalars().all()
        assert rows
        assert all(row.status == "deleted" for row in rows)
