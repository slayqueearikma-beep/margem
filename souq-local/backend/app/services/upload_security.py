"""Upload filename/content-type checks and media URL allowlisting."""

from __future__ import annotations

import re
from pathlib import PurePosixPath
from urllib.parse import unquote, urlparse
from uuid import UUID

from app.config import settings
from app.services.media_urls import all_minio_buckets, owner_user_id_from_object_key, parse_media_url

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}
_MAX_FILENAME_LENGTH = 120
_AZURE_BLOB_HOST_SUFFIXES = (
    ".blob.core.windows.net",
    ".blob.storage.azure.net",
)


def validate_presign_upload_url(
    upload_url: str,
    *,
    public_api_url: str,
    allowed_hosts: list[str] | None = None,
) -> None:
    """Ensure presigned upload targets only our API, Azure Blob, or MinIO."""
    parsed = urlparse(upload_url.strip())
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Upload URL must use http(s)")

    host = (parsed.hostname or "").lower()
    if not host:
        raise ValueError("Upload URL host is missing")

    api_host = (urlparse(public_api_url.rstrip("/")).hostname or "").lower()
    extra_hosts = {h.lower() for h in (allowed_hosts or []) if h}

    minio_host = ""
    if settings.minio_endpoint:
        minio_host = (urlparse(settings.minio_endpoint.rstrip("/")).hostname or "").lower()
    if settings.minio_public_url:
        minio_host = minio_host or (urlparse(settings.minio_public_url.rstrip("/")).hostname or "").lower()

    if (
        host == api_host
        or any(host.endswith(suffix) for suffix in _AZURE_BLOB_HOST_SUFFIXES)
        or (minio_host and host == minio_host)
        or host in extra_hosts
    ):
        return
    raise ValueError("Upload URL host is not allowed")


def sanitize_upload_filename(filename: str) -> str:
    name = PurePosixPath(filename).name
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name).strip("._")
    if not name:
        raise ValueError("Invalid filename")
    return name[:_MAX_FILENAME_LENGTH]


def validate_upload_content_type(content_type: str) -> None:
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise ValueError(f"Unsupported content type: {content_type}")


def validate_image_bytes(data: bytes, content_type: str) -> None:
    """Reject mislabeled/non-image uploads without trusting the HTTP header."""
    if content_type == "image/jpeg":
        valid = data.startswith(b"\xff\xd8\xff") and data.rstrip().endswith(b"\xff\xd9")
    elif content_type == "image/png":
        valid = data.startswith(b"\x89PNG\r\n\x1a\n")
    elif content_type == "image/gif":
        valid = data.startswith((b"GIF87a", b"GIF89a"))
    elif content_type == "image/webp":
        valid = len(data) >= 12 and data.startswith(b"RIFF") and data[8:12] == b"WEBP"
    else:
        valid = False
    if not valid:
        raise ValueError("Upload bytes do not match the declared image type")


def _validate_owner_for_object_key(object_key: str, owner_user_id: UUID) -> None:
    owner = owner_user_id_from_object_key(object_key)
    if owner != str(owner_user_id):
        raise ValueError("Media URL must belong to the authenticated user")


def validate_media_url(
    url: str,
    *,
    owner_user_id: UUID | None = None,
    container: str | None = None,
    public_api_url: str | None = None,
    minio_public_url: str | None = None,
    storage_provider: str | None = None,
) -> str:
    """Ensure image URLs point at allowed storage locations.

    Empty string is allowed (no image). Rejects javascript:, data:, and foreign hosts.
    """
    _ = (container, minio_public_url, storage_provider)  # backward-compatible kwargs
    value = (url or "").strip()
    if not value:
        return ""

    parsed = urlparse(value)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Media URL must use http(s)")

    api_base = (public_api_url or settings.public_api_url or "").rstrip("/")
    host = (parsed.hostname or "").lower()
    path = unquote(parsed.path or "")

    parsed_ref = parse_media_url(value)
    if parsed_ref is not None:
        bucket, object_key = parsed_ref
        if bucket in all_minio_buckets() or bucket in {settings.azure_storage_container, "local"}:
            if owner_user_id is not None:
                _validate_owner_for_object_key(object_key, owner_user_id)
            return value

    # Local media: {PUBLIC_API_URL}/media/{object_key...}
    if api_base:
        base = urlparse(api_base)
        base_host = (base.hostname or "").lower()
        if base_host and host == base_host and path.startswith("/media/"):
            parts = [p for p in path.split("/") if p]
            if len(parts) < 2 or parts[0] != "media":
                raise ValueError("Media URL path is not allowed")
            if parts[1] in all_minio_buckets():
                object_key = "/".join(parts[2:])
            else:
                object_key = "/".join(parts[1:])
            if owner_user_id is not None:
                _validate_owner_for_object_key(object_key, owner_user_id)
            return value

    if parsed.scheme != "https":
        raise ValueError("Media URL must use https")

    if settings.minio_public_url and settings.effective_storage_provider == "selfhosted":
        from app.services.minio_storage import validate_minio_public_url

        return validate_minio_public_url(value, owner_user_id=owner_user_id)

    container_name = container or settings.azure_storage_container
    if not any(host.endswith(suffix) for suffix in _AZURE_BLOB_HOST_SUFFIXES):
        raise ValueError("Media URL host is not allowed")

    parts = [p for p in path.split("/") if p]
    if len(parts) < 2 or parts[0] != container_name:
        raise ValueError("Media URL path is not allowed")

    if owner_user_id is not None:
        object_key = "/".join(parts[1:])
        _validate_owner_for_object_key(object_key, owner_user_id)

    return value
