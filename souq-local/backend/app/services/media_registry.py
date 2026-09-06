"""Track uploaded media objects and support replacement/deletion lifecycle."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import UserMediaObject
from app.services.media_lifecycle import blob_key_from_media_url, delete_media_url, log_media_event


async def register_media_object(
    session: AsyncSession,
    *,
    user_id: UUID,
    public_url: str,
    purpose: str,
    content_type: str = "",
    bytes_size: int = 0,
) -> UserMediaObject | None:
    blob_key = blob_key_from_media_url(public_url)
    if not blob_key:
        return None
    stmt = (
        insert(UserMediaObject)
        .values(
            user_id=user_id,
            blob_key=blob_key,
            public_url=public_url,
            purpose=purpose,
            content_type=content_type,
            bytes_size=bytes_size,
            status="active",
        )
        .on_conflict_do_update(
            index_elements=["blob_key"],
            set_={
                "public_url": public_url,
                "purpose": purpose,
                "content_type": content_type,
                "bytes_size": bytes_size,
                "status": "active",
                "deleted_at": None,
            },
        )
        .returning(UserMediaObject)
    )
    row = (await session.execute(stmt)).scalar_one()
    log_media_event("profile_photo_uploaded", user_id=user_id, purpose=purpose)
    return row


async def supersede_media_url(session: AsyncSession, *, user_id: UUID, old_url: str) -> None:
    if not old_url:
        return
    blob_key = blob_key_from_media_url(old_url)
    if blob_key:
        await session.execute(
            update(UserMediaObject)
            .where(
                UserMediaObject.user_id == user_id,
                UserMediaObject.blob_key == blob_key,
                UserMediaObject.status == "active",
            )
            .values(status="superseded", deleted_at=datetime.now(UTC))
        )
    await delete_media_url(old_url)
    log_media_event("profile_photo_replaced", user_id=user_id, detail=blob_key or "")


async def require_registered_media(
    session: AsyncSession,
    *,
    user_id: UUID,
    public_url: str,
) -> None:
    """Ensure media was uploaded and server-validated before attaching to listings."""
    cleaned = (public_url or "").strip()
    if not cleaned:
        return
    blob_key = blob_key_from_media_url(cleaned)
    if not blob_key:
        raise ValueError("Invalid media URL")
    row = await session.scalar(
        select(UserMediaObject).where(
            UserMediaObject.user_id == user_id,
            UserMediaObject.blob_key == blob_key,
            UserMediaObject.status == "active",
        )
    )
    if row is None:
        raise ValueError(
            "Media must be uploaded and validated before use. "
            "Complete the upload validation step first."
        )


async def mark_user_media_deleted(session: AsyncSession, user_id: UUID) -> None:
    await session.execute(
        update(UserMediaObject)
        .where(UserMediaObject.user_id == user_id, UserMediaObject.status.in_(("active", "superseded")))
        .values(status="deleted", deleted_at=datetime.now(UTC))
    )
