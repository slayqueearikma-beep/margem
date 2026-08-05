"""Moderation helpers for city community chat."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User
from app.models.community import (
    CommunityCityBan,
    CommunityMembership,
    CommunityMessage,
    CommunityMessageStatus,
    CommunityModerationLog,
    CommunityReport,
    CommunityReportStatus,
    CommunityUserBlock,
    CommunityUserMute,
)

URL_PATTERN = re.compile(r"https?://", re.I)
MENTION_PATTERN = re.compile(r"@([a-zA-Z0-9_]{2,32})")
HASHTAG_PATTERN = re.compile(r"#([a-zA-Z0-9_]{2,32})")
SCAM_KEYWORDS = ("send money", "wire transfer", "crypto giveaway", "whatsapp only", "pay first")


def extract_mentions(body: str) -> list[str]:
    return list({m.group(1).lower() for m in MENTION_PATTERN.finditer(body)})


def extract_hashtags(body: str) -> list[str]:
    return list({m.group(1).lower() for m in HASHTAG_PATTERN.finditer(body)})


def detect_language(body: str) -> str:
    if re.search(r"[\u0600-\u06FF]", body):
        return "ar"
    if re.search(r"[àâçéèêëïîôùûü]", body, re.I):
        return "fr"
    return "en"


def compute_spam_score(body: str, *, recent_duplicate: bool) -> tuple[float, str]:
    score = 0.0
    reasons: list[str] = []
    normalized = body.strip()

    if not normalized and not body:
        return 1.0, "empty"

    if recent_duplicate:
        score += 0.45
        reasons.append("duplicate")

    if len(normalized) > 20 and normalized == normalized.upper():
        score += 0.2
        reasons.append("all_caps")

    link_count = len(URL_PATTERN.findall(normalized))
    if link_count >= 3:
        score += 0.35
        reasons.append("excessive_links")

    lowered = normalized.lower()
    for keyword in SCAM_KEYWORDS:
        if keyword in lowered:
            score += 0.4
            reasons.append("scam_pattern")
            break

    if re.search(r"(.)\1{6,}", normalized):
        score += 0.15
        reasons.append("repeated_chars")

    return min(score, 1.0), ",".join(reasons)


async def is_duplicate_message(
    session: AsyncSession,
    *,
    channel_id: UUID,
    sender_id: UUID,
    body: str,
    window_seconds: int = 60,
) -> bool:
    since = datetime.now(UTC) - timedelta(seconds=window_seconds)
    existing = await session.scalar(
        select(CommunityMessage.id)
        .where(
            CommunityMessage.channel_id == channel_id,
            CommunityMessage.sender_id == sender_id,
            CommunityMessage.body == body,
            CommunityMessage.created_at >= since,
            CommunityMessage.status != CommunityMessageStatus.DELETED,
        )
        .limit(1)
    )
    return existing is not None


async def ensure_not_banned(session: AsyncSession, *, city_id: UUID, user_id: UUID) -> None:
    ban = await session.scalar(
        select(CommunityCityBan).where(
            CommunityCityBan.city_id == city_id,
            CommunityCityBan.user_id == user_id,
        )
    )
    if ban is None:
        return
    if ban.expires_at and ban.expires_at < datetime.now(UTC):
        await session.delete(ban)
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Banned from this city community")


async def require_city_membership(
    session: AsyncSession,
    *,
    city_id: UUID,
    user_id: UUID,
) -> CommunityMembership:
    membership = await session.scalar(
        select(CommunityMembership).where(
            CommunityMembership.city_id == city_id,
            CommunityMembership.user_id == user_id,
        )
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Join this city community before participating",
        )
    return membership


async def is_blocked(session: AsyncSession, viewer_id: UUID, author_id: UUID) -> bool:
    blocked = await session.scalar(
        select(CommunityUserBlock.id).where(
            and_(
                CommunityUserBlock.blocker_id == viewer_id,
                CommunityUserBlock.blocked_id == author_id,
            )
        )
    )
    return blocked is not None


async def is_muted(session: AsyncSession, viewer_id: UUID, author_id: UUID) -> bool:
    muted = await session.scalar(
        select(CommunityUserMute.id).where(
            and_(
                CommunityUserMute.muter_id == viewer_id,
                CommunityUserMute.muted_id == author_id,
            )
        )
    )
    return muted is not None


async def log_moderation(
    session: AsyncSession,
    *,
    actor_id: UUID | None,
    action: str,
    target_type: str,
    target_id: str,
    metadata: dict | None = None,
) -> None:
    session.add(
        CommunityModerationLog(
            id=uuid4(),
            actor_id=actor_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            metadata_=metadata or {},
        )
    )


async def create_report(
    session: AsyncSession,
    *,
    message: CommunityMessage,
    reporter: User,
    reason: str,
    details: str,
) -> CommunityReport:
    report = CommunityReport(
        id=uuid4(),
        message_id=message.id,
        reporter_id=reporter.id,
        reason=reason,
        details=details,
        status=CommunityReportStatus.OPEN,
    )
    session.add(report)
    await log_moderation(
        session,
        actor_id=reporter.id,
        action="report_message",
        target_type="message",
        target_id=str(message.id),
        metadata={"reason": reason},
    )
    return report
