from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import User
from app.schemas import PresignRequest, PresignResponse
from app.services.local_storage import (
    public_media_url,
    verify_minio_upload_token,
    verify_upload_token,
    write_local_blob,
)
from app.services.storage_provider import (
    get_storage_provider,
    purpose_from_string,
)
from app.services.upload_security import (
    sanitize_upload_filename,
    validate_image_bytes,
    validate_presign_upload_url,
    validate_upload_content_type,
)

router = APIRouter(prefix="/uploads", tags=["uploads"])


def _validate_presign_response(response: PresignResponse) -> PresignResponse:
    try:
        validate_presign_upload_url(
            response.upload_url,
            public_api_url=settings.public_api_url,
            allowed_hosts=settings.upload_allowed_hosts,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Storage returned an invalid upload URL",
        ) from exc
    return response


@router.post("/presign", response_model=PresignResponse)
@limiter.limit("20/minute")
async def presign_upload(
    request: Request,
    payload: PresignRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PresignResponse:
    try:
        safe_filename = sanitize_upload_filename(payload.filename)
        validate_upload_content_type(payload.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    purpose = purpose_from_string(payload.purpose)
    provider = get_storage_provider()

    try:
        result = await provider.presign_upload(
            user=user,
            filename=safe_filename,
            content_type=payload.content_type,
            purpose=purpose,
        )
        provider.log_event("storage_upload_success", user_id=user.id, purpose=purpose.value)
        return _validate_presign_response(
            PresignResponse(upload_url=result.upload_url, public_url=result.public_url)
        )
    except HTTPException:
        raise
    except ValueError as exc:
        provider.log_event("storage_upload_failure", user_id=user.id, detail=str(exc))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Storage configuration error: {exc}",
        ) from exc
    except Exception as exc:
        import logging

        logging.getLogger("margem.storage").exception("presign_failed")
        provider.log_event("storage_upload_failure", user_id=user.id, detail=type(exc).__name__)
        hint = type(exc).__name__
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Storage service unavailable ({hint}).",
        ) from exc


@router.put("/local/{token}")
@limiter.limit("30/minute")
async def put_local_upload(
    token: str,
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Response:
    """Receive a PUT from the mobile client for STORAGE_PROVIDER=local."""
    if settings.effective_storage_provider != "local":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Local storage disabled")

    try:
        meta = verify_upload_token(token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    if meta["user_id"] != str(user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Upload token belongs to another user")

    content_type = (request.headers.get("content-type") or meta["content_type"]).split(";")[0].strip()
    try:
        validate_upload_content_type(content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    body = await request.body()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty upload body")

    if len(body) > settings.max_upload_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Image too large")

    try:
        validate_image_bytes(body, content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    from app.services.image_processing import sanitize_image_bytes

    try:
        sanitized = sanitize_image_bytes(body, content_type=content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    try:
        write_local_blob(meta["blob_name"], sanitized.data)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    from app.services.media_lifecycle import log_media_event
    from app.services.media_registry import register_media_object

    public_url = public_media_url(meta["blob_name"])
    await register_media_object(
        session,
        user_id=user.id,
        public_url=public_url,
        purpose="upload",
        content_type=sanitized.content_type,
        bytes_size=len(sanitized.data),
    )
    await session.commit()
    log_media_event(
        "profile_photo_uploaded",
        user_id=user.id,
        purpose="upload",
        detail=f"bytes={len(sanitized.data)}",
    )

    return Response(status_code=status.HTTP_201_CREATED)


@router.put("/storage/{token}")
@limiter.limit("30/minute")
async def put_storage_upload(
    token: str,
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Response:
    """Receive a PUT for self-hosted MinIO when MINIO_PUBLIC_URL is not configured."""
    if settings.effective_storage_provider != "selfhosted":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Self-hosted storage disabled")

    try:
        meta = verify_minio_upload_token(token)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    if meta["user_id"] != str(user.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Upload token belongs to another user")

    content_type = (request.headers.get("content-type") or meta["content_type"]).split(";")[0].strip()
    try:
        validate_upload_content_type(content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    body = await request.body()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty upload body")

    if len(body) > settings.max_upload_bytes:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Image too large")

    try:
        validate_image_bytes(body, content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    from app.services.image_processing import sanitize_image_bytes
    from app.services.media_lifecycle import log_media_event
    from app.services.media_registry import register_media_object
    from app.services.minio_storage import all_buckets, api_media_url, put_object_bytes

    try:
        sanitized = sanitize_image_bytes(body, content_type=content_type)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    bucket = meta["bucket"]
    if bucket not in all_buckets():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid upload bucket")
    put_object_bytes(
        bucket=bucket,
        object_key=meta["object_key"],
        data=sanitized.data,
        content_type=sanitized.content_type,
    )
    public_url = api_media_url(bucket=bucket, object_key=meta["object_key"])
    await register_media_object(
        session,
        user_id=user.id,
        public_url=public_url,
        purpose="upload",
        content_type=sanitized.content_type,
        bytes_size=len(sanitized.data),
    )
    await session.commit()
    log_media_event(
        "profile_photo_uploaded",
        user_id=user.id,
        purpose="upload",
        detail=f"bytes={len(sanitized.data)}",
    )
    return Response(status_code=status.HTTP_201_CREATED)


class ValidateUploadRequest(BaseModel):
    public_url: str = Field(max_length=2048)
    content_type: str = Field(max_length=64)


@router.post("/validate")
@limiter.limit("30/minute")
async def validate_uploaded_blob(
    request: Request,
    payload: ValidateUploadRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Server-side validation for direct-to-storage uploads."""
    from app.services.image_processing import sanitize_image_bytes
    from app.services.media_registry import register_media_object
    from app.services.media_urls import parse_media_url
    from app.services.storage_provider import get_storage_provider

    provider = get_storage_provider()
    try:
        validate_upload_content_type(payload.content_type)
        provider.validate_owner_url(payload.public_url, owner_user_id=user.id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    parsed = parse_media_url(payload.public_url)
    body: bytes
    if settings.effective_storage_provider == "local":
        from app.services.local_storage import media_root

        if parsed and parsed[0] == "local":
            key = parsed[1]
        else:
            raise HTTPException(status_code=400, detail="Invalid media URL")
        path = (media_root() / key).resolve()
        if not path.is_file():
            raise HTTPException(status_code=400, detail="Uploaded blob is not readable")
        body = path.read_bytes()
    elif settings.effective_storage_provider == "selfhosted":
        from app.services.minio_storage import all_buckets, get_object_bytes

        if not parsed or parsed[0] not in all_buckets():
            raise HTTPException(status_code=400, detail="Invalid media URL")
        bucket, object_key = parsed
        try:
            body, _ = get_object_bytes(bucket=bucket, object_key=object_key)
        except Exception as exc:
            provider.log_event("storage_upload_failure", user_id=user.id, detail="object_unreadable")
            raise HTTPException(status_code=400, detail="Uploaded blob is not readable") from exc
    elif parsed and parsed[0] == settings.azure_storage_container:
        import httpx

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(payload.public_url)
            if response.status_code != 200:
                raise HTTPException(status_code=400, detail="Uploaded blob is not readable")
            body = response.content
    else:
        raise HTTPException(status_code=400, detail="Validation not supported for this storage backend")

    if len(body) > settings.max_upload_bytes:
        raise HTTPException(status_code=413, detail="Image too large")
    try:
        validate_image_bytes(body, payload.content_type)
        sanitized = sanitize_image_bytes(body, content_type=payload.content_type)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    await register_media_object(
        session,
        user_id=user.id,
        public_url=payload.public_url,
        purpose="upload_validated",
        content_type=sanitized.content_type,
        bytes_size=len(sanitized.data),
    )
    await session.commit()
    provider.log_event("storage_upload_success", user_id=user.id, detail="validated")
    return {"status": "valid", "bytes": len(sanitized.data)}


__all__ = ["router"]
