"""Controlled media delivery — proxies MinIO objects through the API."""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Response, status
from fastapi.responses import Response as FastAPIResponse

from app.config import settings
from app.services.minio_storage import all_buckets, get_object_bytes

logger = logging.getLogger("margem.storage")

router = APIRouter(tags=["media"])


@router.get("/media/{bucket}/{path:path}", include_in_schema=False)
async def serve_media_object(bucket: str, path: str) -> Response:
    """Serve self-hosted objects via the API (MinIO stays on the internal network)."""
    if settings.effective_storage_provider != "selfhosted":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    if bucket not in all_buckets():
        logger.info("storage_access_denied bucket=%s reason=unknown_bucket", bucket)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    if ".." in path or path.startswith("/"):
        logger.info("storage_access_denied bucket=%s reason=invalid_path", bucket)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    object_key = path.lstrip("/")
    try:
        data, content_type = get_object_bytes(bucket=bucket, object_key=object_key)
    except Exception:
        logger.exception("storage_access_failed bucket=%s key=%s", bucket, object_key)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from None

    return FastAPIResponse(
        content=data,
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=86400",
            "X-Content-Type-Options": "nosniff",
        },
    )
