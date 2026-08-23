"""Object-storage lifecycle helpers for user media (profile photos, seller logos, etc.)."""

from __future__ import annotations

import logging
from urllib.parse import unquote, urlparse
from uuid import UUID

from app.config import settings

logger = logging.getLogger("margem.storage")

_AZURE_HOST_SUFFIX = ".blob.core.windows.net"


def blob_key_from_media_url(url: str) -> str | None:
    """Extract `{user_id}/{uuid}-file` blob key from a stored media URL."""
    value = (url or "").strip()
    if not value:
        return None
    parsed = urlparse(value)
    path = unquote(parsed.path or "")
    parts = [p for p in path.split("/") if p]

    if settings.public_api_url:
        base = urlparse(settings.public_api_url.rstrip("/"))
        if (parsed.hostname or "").lower() == (base.hostname or "").lower() and path.startswith("/media/"):
            if len(parts) >= 3 and parts[0] == "media":
                return "/".join(parts[1:])

    if settings.minio_public_url:
        allowed = urlparse(settings.minio_public_url.rstrip("/"))
        bucket = settings.minio_bucket.strip("/")
        if (parsed.scheme, parsed.netloc) == (allowed.scheme, allowed.netloc):
            prefix = f"/{bucket}/"
            if path.startswith(prefix):
                rest = path[len(prefix) :]
                return rest.lstrip("/") or None

    host = (parsed.hostname or "").lower()
    if host.endswith(_AZURE_HOST_SUFFIX):
        container = settings.azure_storage_container
        if len(parts) >= 2 and parts[0] == container:
            return "/".join(parts[1:])
    return None


async def delete_media_url(url: str) -> bool:
    key = blob_key_from_media_url(url)
    if not key:
        logger.warning("media_delete_skipped unparseable_url")
        return False
    return await delete_blob_key(key)


async def delete_blob_key(blob_key: str) -> bool:
    if not blob_key or ".." in blob_key or blob_key.startswith("/"):
        return False
    backend = settings.storage_backend
    try:
        if backend == "local":
            from app.services.local_storage import delete_local_blob

            return delete_local_blob(blob_key)
        if backend == "minio":
            from app.services.minio_storage import delete_object

            return delete_object(blob_key)
        from app.services.azure_storage import delete_blob

        return await delete_blob(blob_key)
    except Exception:
        logger.exception("media_delete_failed blob_key=%s backend=%s", blob_key, backend)
        return False


async def delete_all_user_media(user_id: UUID) -> int:
    """Delete every object stored under `{user_id}/` prefix (idempotent)."""
    prefix = f"{user_id}/"
    backend = settings.storage_backend
    deleted = 0
    try:
        if backend == "local":
            from app.services.local_storage import delete_user_prefix

            deleted = delete_user_prefix(prefix)
        elif backend == "minio":
            from app.services.minio_storage import delete_prefix

            deleted = delete_prefix(prefix)
        else:
            from app.services.azure_storage import delete_prefix

            deleted = await delete_prefix(prefix)
    except Exception:
        logger.exception("user_media_purge_failed user_id=%s", user_id)
    if deleted:
        logger.info("user_media_purged user_id=%s count=%s", user_id, deleted)
    return deleted


def log_media_event(event: str, *, user_id: UUID | str, purpose: str = "", detail: str = "") -> None:
    logger.info(
        "media_event event=%s user_id=%s purpose=%s detail=%s",
        event,
        user_id,
        purpose,
        detail,
    )
