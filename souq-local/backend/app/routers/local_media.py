"""Controlled local disk media delivery."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Response, status
from fastapi.responses import Response as FastAPIResponse

from app.auth import get_current_user_optional
from app.config import settings
from app.models import User
from app.services.local_storage import media_root
from app.services.media_access import is_public_local_object_key, user_may_read_object

logger = logging.getLogger("margem.storage")

router = APIRouter(tags=["media"])


@router.get("/media/{path:path}", include_in_schema=False)
async def serve_local_media_object(
    path: str,
    user: User | None = Depends(get_current_user_optional),
) -> Response:
    if settings.effective_storage_provider != "local":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    if ".." in path or path.startswith("/"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    object_key = path.lstrip("/")
    if not is_public_local_object_key(object_key):
        if not user_may_read_object(object_key=object_key, user_id=str(user.id) if user else None):
            logger.info("storage_access_denied key=%s reason=restricted", object_key)
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    root = media_root()
    target = (root / object_key).resolve()
    if not str(target).startswith(str(root)) or not target.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    data = target.read_bytes()
    content_type = "application/octet-stream"
    if object_key.lower().endswith(".jpg") or object_key.lower().endswith(".jpeg"):
        content_type = "image/jpeg"
    elif object_key.lower().endswith(".png"):
        content_type = "image/png"
    elif object_key.lower().endswith(".webp"):
        content_type = "image/webp"

    return FastAPIResponse(
        content=data,
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=86400",
            "X-Content-Type-Options": "nosniff",
        },
    )
