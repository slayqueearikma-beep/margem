"""Media read-access policy for API-proxied storage."""

from __future__ import annotations

from app.config import settings
from app.services.media_urls import owner_user_id_from_object_key

_PUBLIC_LOCAL_PREFIXES = ("profiles/", "products/", "listings/", "uploads/")


def is_public_media_bucket(bucket: str) -> bool:
    """Buckets whose objects may be served without authentication."""
    return bucket in {
        settings.minio_bucket_profiles,
        settings.minio_bucket_products,
        settings.minio_bucket_listings,
    }


def is_restricted_media_bucket(bucket: str) -> bool:
    return not is_public_media_bucket(bucket)


def is_public_local_object_key(object_key: str) -> bool:
    key = object_key.lstrip("/")
    return any(key.startswith(prefix) for prefix in _PUBLIC_LOCAL_PREFIXES)


def user_may_read_object(*, object_key: str, user_id: str | None) -> bool:
    if user_id is None:
        return False
    owner = owner_user_id_from_object_key(object_key)
    return owner is not None and owner == user_id


def validate_checkout_redirect_url(custom: str, *, default_suffix: str) -> str:
    """Allow checkout redirects to the configured app origin or approved app deep links."""
    from urllib.parse import urlparse

    value = (custom or "").strip()
    if not value:
        return f"{settings.public_app_url.rstrip('/')}{default_suffix}"

    parsed = urlparse(value)
    if parsed.scheme in {"margem", "dribex"}:
        return value

    allowed = urlparse(settings.public_app_url.rstrip("/"))
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return f"{settings.public_app_url.rstrip('/')}{default_suffix}"
    if (parsed.hostname or "").lower() != (allowed.hostname or "").lower():
        return f"{settings.public_app_url.rstrip('/')}{default_suffix}"
    if parsed.port != allowed.port:
        return f"{settings.public_app_url.rstrip('/')}{default_suffix}"
    return value
