"""MinIO / S3-compatible object storage for on-prem production."""

from __future__ import annotations

import logging
from datetime import timedelta
from urllib.parse import quote, urlparse

from minio import Minio

from app.config import settings

logger = logging.getLogger("margem.storage")


def _client() -> Minio:
    endpoint = settings.minio_endpoint.strip()
    if not endpoint:
        raise ValueError("MINIO_ENDPOINT is not configured")
    parsed = urlparse(endpoint if "://" in endpoint else f"http://{endpoint}")
    host = parsed.netloc or parsed.path
    secure = parsed.scheme == "https"
    if not settings.minio_access_key or not settings.minio_secret_key:
        raise ValueError("MINIO_ACCESS_KEY and MINIO_SECRET_KEY are required")
    return Minio(
        host,
        access_key=settings.minio_access_key,
        secret_key=settings.minio_secret_key,
        secure=secure,
        region=settings.minio_region or None,
    )


def all_buckets() -> tuple[str, ...]:
    return (
        settings.minio_bucket_profiles,
        settings.minio_bucket_products,
        settings.minio_bucket_listings,
        settings.minio_bucket_private,
        settings.minio_bucket,
    )


def ensure_bucket(client: Minio, bucket: str) -> None:
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        logger.info("minio_bucket_created bucket=%s", bucket)


def ensure_buckets() -> None:
    client = _client()
    for bucket in all_buckets():
        ensure_bucket(client, bucket)


def api_media_url(*, bucket: str, object_key: str) -> str:
    """Controlled public URL served by the Dribex API (not direct MinIO access)."""
    encoded_key = "/".join(quote(part, safe="") for part in object_key.split("/"))
    return f"{settings.public_api_url.rstrip('/')}/media/{bucket}/{encoded_key}"


def presign_put_for_bucket(*, bucket: str, object_key: str) -> tuple[str, str]:
    client = _client()
    ensure_bucket(client, bucket)
    upload_url = client.presigned_put_object(
        bucket,
        object_key,
        expires=timedelta(minutes=15),
    )
    access_url = api_media_url(bucket=bucket, object_key=object_key)
    logger.info("storage_upload_presigned bucket=%s key=%s", bucket, object_key)
    return upload_url, access_url


def presign_put(*, blob_name: str) -> tuple[str, str]:
    """Legacy single-bucket presign (migration compatibility)."""
    return presign_put_for_bucket(bucket=settings.minio_bucket, object_key=blob_name)


def public_object_url(blob_name: str) -> str:
    """Legacy direct MinIO URL — prefer api_media_url for new uploads."""
    base = settings.minio_public_url.rstrip("/")
    bucket = settings.minio_bucket.strip("/")
    return f"{base}/{bucket}/{blob_name}"


def get_object_bytes(*, bucket: str, object_key: str) -> tuple[bytes, str]:
    client = _client()
    response = client.get_object(bucket, object_key)
    try:
        data = response.read()
        content_type = response.headers.get("Content-Type") or "application/octet-stream"
        return data, content_type
    finally:
        response.close()
        response.release_conn()


def delete_object_in_bucket(bucket: str, object_key: str) -> bool:
    client = _client()
    try:
        client.remove_object(bucket, object_key)
        logger.info("storage_delete_success bucket=%s key=%s", bucket, object_key)
        return True
    except Exception:
        logger.exception("storage_delete_failure bucket=%s key=%s", bucket, object_key)
        return False


def delete_object(blob_key: str) -> bool:
    return delete_object_in_bucket(settings.minio_bucket, blob_key)


def delete_prefix_in_bucket(bucket: str, prefix: str) -> int:
    client = _client()
    count = 0
    for obj in client.list_objects(bucket, prefix=prefix, recursive=True):
        client.remove_object(bucket, obj.object_name)
        count += 1
    if count:
        logger.info("storage_prefix_deleted bucket=%s prefix=%s count=%s", bucket, prefix, count)
    return count


def delete_prefix(prefix: str) -> int:
    return delete_prefix_in_bucket(settings.minio_bucket, prefix)


def validate_minio_public_url(url: str, *, owner_user_id) -> str:
    """Validate legacy direct MinIO URLs (existing objects during migration)."""
    from uuid import UUID

    from app.services.media_urls import owner_user_id_from_object_key, parse_media_url

    value = (url or "").strip()
    if not value:
        return ""

    parsed_ref = parse_media_url(value)
    if parsed_ref is not None:
        bucket, object_key = parsed_ref
        if bucket in all_buckets() or bucket == settings.azure_storage_container:
            if owner_user_id is not None:
                owner = owner_user_id_from_object_key(object_key)
                if owner != str(owner_user_id):
                    raise ValueError("Media URL does not belong to this user")
            return value

    parsed = urlparse(value)
    allowed = urlparse(settings.minio_public_url.rstrip("/"))
    if (parsed.scheme, parsed.netloc) != (allowed.scheme, allowed.netloc):
        raise ValueError("Media URL host is not allowed")
    prefix = f"/{settings.minio_bucket.strip('/')}/"
    if not parsed.path.startswith(prefix):
        raise ValueError("Media URL path is not allowed")
    if owner_user_id is not None:
        rest = parsed.path[len(prefix) :].lstrip("/")
        owner = owner_user_id_from_object_key(rest)
        if owner != str(owner_user_id):
            raise ValueError("Media URL does not belong to this user")
    return value
