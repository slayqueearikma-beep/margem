"""In-app platform announcements for admin staff."""

from __future__ import annotations

import logging
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AccountType, SellerProfile, User, UserStatus
from app.services.notifications import notify_user

logger = logging.getLogger("margem.admin.announcements")

_BATCH_SIZE = 500
_VALID_AUDIENCES = frozenset({"all", "buyers", "sellers", "premium"})


async def _audience_user_ids(session: AsyncSession, audience: str) -> list[UUID]:
    if audience not in _VALID_AUDIENCES:
        raise ValueError(f"Invalid audience: {audience}")

    stmt = select(User.id).where(User.status == UserStatus.ACTIVE)
    if audience == "buyers":
        stmt = stmt.where(User.account_type == AccountType.BUYER)
    elif audience == "sellers":
        stmt = stmt.where(
            User.id.in_(select(SellerProfile.user_id).where(SellerProfile.is_active.is_(True)))
        )
    elif audience == "premium":
        stmt = stmt.where(User.is_premium.is_(True))

    result = await session.execute(stmt)
    return list(result.scalars().all())


async def send_platform_announcement(
    session: AsyncSession,
    *,
    title: str,
    body: str,
    audience: str = "all",
) -> int:
    """Create in-app notifications for the selected audience. Returns delivery count."""
    user_ids = await _audience_user_ids(session, audience)
    sent = 0
    for user_id in user_ids:
        await notify_user(
            session,
            user_id=user_id,
            title=title,
            body=body,
            kind="announcement",
            data={"audience": audience},
        )
        sent += 1
        if sent % _BATCH_SIZE == 0:
            await session.flush()
    await session.flush()
    logger.info("announcement_sent audience=%s count=%s", audience, sent)
    return sent
