"""Seller video duration validation — enforced on upload and publish."""

from __future__ import annotations

import struct
from uuid import UUID

MAX_VIDEO_DURATION_SECONDS = 59.0
MAX_VIDEO_DURATION_EXCLUSIVE = 60.0


def validate_video_duration_seconds(duration: float) -> None:
    """Raise ValueError when duration is outside 0–59 seconds."""
    if duration < 0:
        raise ValueError("Invalid video duration")
    if duration >= MAX_VIDEO_DURATION_EXCLUSIVE:
        raise ValueError("Video must be less than 1 minute")


def mp4_duration_seconds(data: bytes) -> float | None:
    """Parse MP4/MOV duration from the moov/mvhd atom tree."""

    def _read_u32(offset: int) -> int:
        return struct.unpack(">I", data[offset : offset + 4])[0]

    def _find_mvhd(start: int, end: int) -> float | None:
        offset = start
        while offset + 8 <= end:
            size = _read_u32(offset)
            if size < 8:
                break
            atom_end = min(offset + size, end)
            atom_type = data[offset + 4 : offset + 8]
            content_start = offset + 8
            if atom_type == b"moov":
                found = _find_mvhd(content_start, atom_end)
                if found is not None:
                    return found
            elif atom_type == b"mvhd" and content_start + 20 <= atom_end:
                version = data[content_start]
                if version == 0:
                    timescale = _read_u32(content_start + 12)
                    duration = _read_u32(content_start + 16)
                else:
                    timescale = _read_u32(content_start + 20)
                    duration = struct.unpack(">Q", data[content_start + 24 : content_start + 32])[0]
                if timescale:
                    return float(duration) / float(timescale)
            offset += size
        return None

    if len(data) < 32:
        return None
    return _find_mvhd(0, len(data))


def video_duration_seconds(data: bytes, *, content_type: str) -> float | None:
    ct = (content_type or "").split(";")[0].strip().lower()
    if ct in {"video/mp4", "video/quicktime", "application/octet-stream"}:
        return mp4_duration_seconds(data)
    return None


async def load_owner_media_bytes(*, public_url: str, owner_user_id: UUID) -> bytes:
    """Fetch uploaded media bytes for server-side duration checks."""
    from app.config import settings
    from app.services.media_urls import parse_media_url
    from app.services.storage_provider import get_storage_provider

    provider = get_storage_provider()
    provider.validate_owner_url(public_url, owner_user_id=owner_user_id)

    parsed = parse_media_url(public_url)
    if parsed is None:
        raise ValueError("Invalid media URL")

    if settings.effective_storage_provider == "local":
        from app.services.local_storage import media_root

        if parsed[0] != "local":
            raise ValueError("Invalid media URL")
        path = (media_root() / parsed[1]).resolve()
        if not path.is_file():
            raise ValueError("Uploaded video is not readable")
        return path.read_bytes()

    if settings.effective_storage_provider == "selfhosted":
        from app.services.minio_storage import all_buckets, get_object_bytes

        if parsed[0] not in all_buckets():
            raise ValueError("Invalid media URL")
        body, _ = get_object_bytes(bucket=parsed[0], object_key=parsed[1])
        return body

    if parsed[0] == settings.azure_storage_container:
        import httpx

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(public_url)
            if response.status_code != 200:
                raise ValueError("Uploaded video is not readable")
            return response.content

    raise ValueError("Video validation is not supported for this storage backend")


async def assert_video_duration_from_url(
    *,
    public_url: str,
    owner_user_id: UUID,
    content_type: str,
) -> float:
    body = await load_owner_media_bytes(public_url=public_url, owner_user_id=owner_user_id)
    duration = video_duration_seconds(body, content_type=content_type)
    if duration is None:
        raise ValueError("Could not determine video duration")
    validate_video_duration_seconds(duration)
    return duration
