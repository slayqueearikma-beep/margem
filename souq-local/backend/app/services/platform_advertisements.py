"""Simple platform display advertisements (admin-managed banners)."""

from __future__ import annotations

import re
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import PlatformAdvertisement, User
from app.services.entitlements import build_entitlements
from app.services.url_security import reject_private_or_internal_url

_HTML_TAG_PATTERN = re.compile(r"<[^>]+>")


def sanitize_ad_title(value: str, *, max_len: int = 120) -> str:
    cleaned = _HTML_TAG_PATTERN.sub("", value.strip())
    if not cleaned:
        raise ValueError("Title is required")
    return cleaned[:max_len]


def validate_ad_url(value: str, *, field_name: str) -> str:
    return reject_private_or_internal_url(value.strip(), field_name=field_name)


async def should_show_promotional_ads(session: AsyncSession, user: User | None) -> bool:
    """True when Dribex promotional ads may be displayed to this viewer."""
    if user is None:
        return True
    bundle = await build_entitlements(session, user)
    return bundle.ads_enabled


async def list_active_advertisements(
    session: AsyncSession,
    *,
    user: User | None = None,
    limit: int = 5,
) -> list[PlatformAdvertisement]:
    if not await should_show_promotional_ads(session, user):
        return []
    safe_limit = max(1, min(limit, 20))
    result = await session.execute(
        select(PlatformAdvertisement)
        .where(PlatformAdvertisement.is_active.is_(True))
        .order_by(PlatformAdvertisement.created_at.desc())
        .limit(safe_limit)
    )
    return list(result.scalars().all())


async def get_advertisement(session: AsyncSession, ad_id: UUID) -> PlatformAdvertisement | None:
    return await session.get(PlatformAdvertisement, ad_id)
