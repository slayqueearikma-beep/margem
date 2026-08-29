"""Server-verified rewarded advertisement grants for temporary feature unlocks."""

from __future__ import annotations

import hashlib
import hmac
import logging
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import RewardedAdGrant, RewardedAdSession, RewardedAdSessionStatus

logger = logging.getLogger("margem.rewarded_ads")

FEATURE_SAVED_SEARCH = "saved_search"

REWARD_FEATURE_CONFIG: dict[str, dict[str, int]] = {
    FEATURE_SAVED_SEARCH: {
        "grant_hours": 24 * 7,
        "session_minutes": 15,
        "daily_limit": 1,
    },
}

ALLOWED_REWARD_FEATURES = frozenset(REWARD_FEATURE_CONFIG)


@dataclass(frozen=True)
class RewardGrantStatus:
    feature_code: str
    active: bool
    expires_at: datetime | None


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


def rewarded_ads_operational() -> bool:
    return settings.rewarded_ads_enabled and settings.ads_enabled


def _sign_session_token(session_id: UUID, user_id: UUID, feature_code: str, expires_at: datetime) -> str:
    secret = settings.rewarded_ad_signing_secret.encode("utf-8")
    payload = f"{session_id}:{user_id}:{feature_code}:{int(_aware(expires_at).timestamp())}"
    return hmac.new(secret, payload.encode("utf-8"), hashlib.sha256).hexdigest()


def verify_session_token(
    *,
    session_id: UUID,
    user_id: UUID,
    feature_code: str,
    expires_at: datetime,
    token: str,
) -> bool:
    if not token:
        return False
    expected = _sign_session_token(session_id, user_id, feature_code, expires_at)
    return hmac.compare_digest(expected, token.strip())


async def has_active_reward(
    session: AsyncSession,
    user_id: UUID,
    feature_code: str,
    *,
    now: datetime | None = None,
) -> bool:
    if feature_code not in ALLOWED_REWARD_FEATURES:
        return False
    clock = now or _utc_now()
    grant = await session.scalar(
        select(RewardedAdGrant)
        .where(
            RewardedAdGrant.user_id == user_id,
            RewardedAdGrant.feature_code == feature_code,
            RewardedAdGrant.expires_at >= clock,
        )
        .order_by(RewardedAdGrant.expires_at.desc())
        .limit(1)
    )
    return grant is not None


async def list_active_rewards(
    session: AsyncSession,
    user_id: UUID,
    *,
    now: datetime | None = None,
) -> list[RewardGrantStatus]:
    clock = now or _utc_now()
    result = await session.execute(
        select(RewardedAdGrant)
        .where(RewardedAdGrant.user_id == user_id, RewardedAdGrant.expires_at >= clock)
        .order_by(RewardedAdGrant.feature_code.asc())
    )
    seen: set[str] = set()
    statuses: list[RewardGrantStatus] = []
    for grant in result.scalars().all():
        if grant.feature_code in seen:
            continue
        seen.add(grant.feature_code)
        statuses.append(
            RewardGrantStatus(
                feature_code=grant.feature_code,
                active=True,
                expires_at=_aware(grant.expires_at),
            )
        )
    return statuses


async def _count_daily_completions(
    session: AsyncSession,
    user_id: UUID,
    feature_code: str,
    *,
    now: datetime | None = None,
) -> int:
    clock = now or _utc_now()
    day_start = clock.replace(hour=0, minute=0, second=0, microsecond=0)
    count = await session.scalar(
        select(func.count(RewardedAdGrant.id)).where(
            RewardedAdGrant.user_id == user_id,
            RewardedAdGrant.feature_code == feature_code,
            RewardedAdGrant.granted_at >= day_start,
        )
    )
    return int(count or 0)


async def create_reward_session(
    session: AsyncSession,
    *,
    user_id: UUID,
    feature_code: str,
) -> tuple[RewardedAdSession, str]:
    if not rewarded_ads_operational():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Rewarded advertisements are not available.",
        )
    if feature_code not in ALLOWED_REWARD_FEATURES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported reward feature.")

    config = REWARD_FEATURE_CONFIG[feature_code]
    now = _utc_now()
    if await _count_daily_completions(session, user_id, feature_code, now=now) >= config["daily_limit"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily rewarded-ad limit reached for this feature.",
        )

    expires_at = now + timedelta(minutes=config["session_minutes"])
    reward_session = RewardedAdSession(
        id=uuid4(),
        user_id=user_id,
        feature_code=feature_code,
        status=RewardedAdSessionStatus.PENDING.value,
        expires_at=expires_at,
    )
    session.add(reward_session)
    await session.flush()
    token = _sign_session_token(reward_session.id, user_id, feature_code, expires_at)
    return reward_session, token


async def complete_reward_session(
    session: AsyncSession,
    *,
    user_id: UUID,
    session_id: UUID,
    session_token: str,
    provider: str = "internal",
    provider_reward_id: str | None = None,
) -> RewardedAdGrant:
    if not rewarded_ads_operational():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Rewarded advertisements are not available.",
        )

    reward_session = await session.get(RewardedAdSession, session_id)
    if reward_session is None or reward_session.user_id != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reward session not found.")

    now = _utc_now()
    if reward_session.status != RewardedAdSessionStatus.PENDING.value:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Reward session already completed.")
    if _aware(reward_session.expires_at) < now:
        reward_session.status = RewardedAdSessionStatus.EXPIRED.value
        await session.flush()
        raise HTTPException(status_code=status.HTTP_410_GONE, detail="Reward session expired.")

    if not verify_session_token(
        session_id=session_id,
        user_id=user_id,
        feature_code=reward_session.feature_code,
        expires_at=reward_session.expires_at,
        token=session_token,
    ):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid reward session token.")

    if provider_reward_id:
        existing = await session.scalar(
            select(RewardedAdGrant).where(
                RewardedAdGrant.provider == provider,
                RewardedAdGrant.provider_reward_id == provider_reward_id,
            )
        )
        if existing is not None:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Reward already claimed.")

    config = REWARD_FEATURE_CONFIG[reward_session.feature_code]
    if await _count_daily_completions(session, user_id, reward_session.feature_code, now=now) >= config["daily_limit"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Daily rewarded-ad limit reached for this feature.",
        )

    grant = RewardedAdGrant(
        id=uuid4(),
        user_id=user_id,
        feature_code=reward_session.feature_code,
        session_id=reward_session.id,
        provider=provider,
        provider_reward_id=provider_reward_id,
        expires_at=now + timedelta(hours=config["grant_hours"]),
    )
    reward_session.status = RewardedAdSessionStatus.COMPLETED.value
    reward_session.completed_at = now
    session.add(grant)
    await session.flush()

    logger.info(
        "rewarded_ad_granted user_id=%s feature=%s expires_at=%s provider=%s",
        user_id,
        reward_session.feature_code,
        grant.expires_at.isoformat(),
        provider,
    )
    return grant
