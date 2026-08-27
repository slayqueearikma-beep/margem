"""Object-storage lifecycle helpers for user media (profile photos, seller logos, etc.)."""

from __future__ import annotations

import logging
from uuid import UUID

from app.config import settings

logger = logging.getLogger("margem.storage")

_USER_PREFIXES = (
    "profiles/{user_id}/",
    "products/{user_id}/",
    "listings/{user_id}/",
    "private/{user_id}/",
    "uploads/{user_id}/",
    "{user_id}/",  # legacy layout
)


def blob_key_from_media_url(url: str) -> str | None:
    """Extract object key from a stored media URL (legacy helper)."""
    from app.services.media_urls import blob_key_from_media_url as _extract

    return _extract(url)


def _bucket_for_object_key(provider, blob_key: str) -> str:
    from app.services.storage_provider import StoragePurpose

    if provider.name == "azure":
        return settings.azure_storage_container
    if provider.name == "local":
        return "local"
    purpose_prefixes = {
        "profiles/": StoragePurpose.PROFILE,
        "products/": StoragePurpose.PRODUCT,
        "listings/": StoragePurpose.LISTING,
        "private/": StoragePurpose.PRIVATE,
        "uploads/": StoragePurpose.GENERAL,
    }
    for prefix, purpose in purpose_prefixes.items():
        if blob_key.startswith(prefix):
            return provider.bucket_for(purpose)
    return settings.minio_bucket_private


async def delete_media_url(url: str) -> bool:
    from app.services.storage_provider import get_storage_provider

    provider = get_storage_provider()
    parsed = provider.parse_object_ref(url)
    if not parsed:
        logger.warning("media_delete_skipped unparseable_url")
        return False
    bucket, object_key = parsed
    return await provider.delete_object(bucket=bucket, object_key=object_key)


async def delete_blob_key(blob_key: str) -> bool:
    from app.services.storage_provider import get_storage_provider

    if not blob_key or ".." in blob_key or blob_key.startswith("/"):
        return False
    provider = get_storage_provider()
    bucket = _bucket_for_object_key(provider, blob_key)
    try:
        return await provider.delete_object(bucket=bucket, object_key=blob_key)
    except Exception:
        logger.exception("media_delete_failed blob_key=%s provider=%s", blob_key, provider.name)
        return False


async def delete_all_user_media(user_id: UUID) -> int:
    """Delete every object stored under user prefixes (idempotent)."""
    from app.services.minio_storage import all_buckets
    from app.services.storage_provider import get_storage_provider

    provider = get_storage_provider()
    deleted = 0
    prefixes = [pattern.format(user_id=user_id) for pattern in _USER_PREFIXES]
    try:
        if provider.name == "selfhosted":
            for bucket in all_buckets():
                for prefix in prefixes:
                    deleted += await provider.delete_prefix(bucket=bucket, prefix=prefix)
        else:
            bucket = settings.azure_storage_container if provider.name == "azure" else "local"
            for prefix in prefixes:
                deleted += await provider.delete_prefix(bucket=bucket, prefix=prefix)
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
