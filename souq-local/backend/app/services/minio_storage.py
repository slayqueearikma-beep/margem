"""MinIO / S3-compatible object storage for on-prem production."""

from __future__ import annotations

from datetime import timedelta
from urllib.parse import urlparse
from uuid import UUID

from minio import Minio

from app.config import settings


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


def ensure_bucket(client: Minio) -> None:
    bucket = settings.minio_bucket
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)


def presign_put(*, blob_name: str) -> tuple[str, str]:
    client = _client()
    ensure_bucket(client)
    upload_url = client.presigned_put_object(
        settings.minio_bucket,
        blob_name,
        expires=timedelta(minutes=15),
    )
    public_url = public_object_url(blob_name)
    return upload_url, public_url


def public_object_url(blob_name: str) -> str:
    base = settings.minio_public_url.rstrip("/")
    bucket = settings.minio_bucket.strip("/")
    return f"{base}/{bucket}/{blob_name}"


def validate_minio_public_url(url: str, *, owner_user_id: UUID | None = None) -> str:
    value = (url or "").strip()
    if not value:
        return ""
    parsed = urlparse(value)
    allowed = urlparse(settings.minio_public_url.rstrip("/"))
    if (parsed.scheme, parsed.netloc) != (allowed.scheme, allowed.netloc):
        raise ValueError("Media URL host is not allowed")
    prefix = f"/{settings.minio_bucket.strip('/')}/"
    if not parsed.path.startswith(prefix):
        raise ValueError("Media URL path is not allowed")
    if owner_user_id is not None:
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) < 3 or parts[1] != str(owner_user_id):
            raise ValueError("Media URL does not belong to this user")
    return value
