"""Parse stored media URLs into provider-neutral (bucket, object_key) references."""

from __future__ import annotations

from urllib.parse import unquote, urlparse

from app.config import settings

_AZURE_HOST_SUFFIX = ".blob.core.windows.net"


def all_minio_buckets() -> tuple[str, ...]:
    return (
        settings.minio_bucket_profiles,
        settings.minio_bucket_products,
        settings.minio_bucket_listings,
        settings.minio_bucket_private,
        settings.minio_bucket,
    )


def parse_media_url(url: str) -> tuple[str, str] | None:
    """Return ``(bucket, object_key)`` when *url* is a recognized media URL."""
    value = (url or "").strip()
    if not value:
        return None
    parsed = urlparse(value)
    path = unquote(parsed.path or "")
    parts = [p for p in path.split("/") if p]

    # API proxy: {PUBLIC_API_URL}/media/{bucket}/{object_key...}
    if settings.public_api_url:
        base = urlparse(settings.public_api_url.rstrip("/"))
        if (parsed.hostname or "").lower() == (base.hostname or "").lower() and path.startswith("/media/"):
            if len(parts) < 2 or parts[0] != "media":
                return None
            bucket = parts[1]
            if bucket in all_minio_buckets() or bucket == "local":
                return bucket, "/".join(parts[2:])
            # Legacy local layout: /media/{user_id}/file (no bucket segment)
            if len(parts) >= 2:
                return "local", "/".join(parts[1:])

    # Legacy direct MinIO public URL: {MINIO_PUBLIC_URL}/{bucket}/{key}
    if settings.minio_public_url:
        allowed = urlparse(settings.minio_public_url.rstrip("/"))
        if (parsed.scheme, parsed.netloc) == (allowed.scheme, allowed.netloc):
            for bucket in all_minio_buckets():
                prefix = f"/{bucket.strip('/')}/"
                if path.startswith(prefix):
                    return bucket, path[len(prefix) :].lstrip("/") or None

    host = (parsed.hostname or "").lower()
    if host.endswith(_AZURE_HOST_SUFFIX):
        container = settings.azure_storage_container
        if len(parts) >= 2 and parts[0] == container:
            return container, "/".join(parts[1:])
    return None


def blob_key_from_media_url(url: str) -> str | None:
    """Legacy helper — object key only (no bucket)."""
    parsed = parse_media_url(url)
    if parsed is None:
        return None
    return parsed[1]


def owner_user_id_from_object_key(object_key: str) -> str | None:
    """Extract owning user id from purpose-prefixed or legacy object keys."""
    parts = [p for p in object_key.split("/") if p]
    if len(parts) >= 3 and parts[0] in {
        "profiles",
        "products",
        "listings",
        "private",
        "uploads",
    }:
        return parts[1]
    if len(parts) >= 2:
        return parts[0]
    return None
