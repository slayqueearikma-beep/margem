"""Spam protection for marketplace communities — progressive penalties."""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from difflib import SequenceMatcher
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.marketplace_community import (
    MarketplaceCommunityMessage,
    MarketplaceCommunitySpamState,
    MarketplaceMessageStatus,
)

BASE_MESSAGE_INTERVAL_SECONDS = 2
DUPLICATE_LOOKBACK_SECONDS = 300
NEAR_DUPLICATE_RATIO = 0.92

COOLDOWN_SECONDS_BY_VIOLATION = {
    1: 5,
    2: 15,
    3: 60,
    4: 600,
}

DUPLICATE_MESSAGE = "You've already sent this message."


@dataclass
class SpamCheckResult:
    allowed: bool
    retry_after_seconds: int = 0
    detail: str = ""


def normalize_body(body: str) -> str:
    collapsed = re.sub(r"\s+", " ", body.strip().lower())
    return collapsed


def bodies_are_near_duplicates(left: str, right: str) -> bool:
    if not left or not right:
        return False
    if left == right:
        return True
    return SequenceMatcher(None, left, right).ratio() >= NEAR_DUPLICATE_RATIO


async def get_or_create_spam_state(
    session: AsyncSession, *, user_id: UUID, marketplace_id: UUID
) -> MarketplaceCommunitySpamState:
    state = await session.scalar(
        select(MarketplaceCommunitySpamState).where(
            MarketplaceCommunitySpamState.user_id == user_id,
            MarketplaceCommunitySpamState.marketplace_id == marketplace_id,
        )
    )
    if state is not None:
        return state
    state = MarketplaceCommunitySpamState(
        id=uuid4(),
        user_id=user_id,
        marketplace_id=marketplace_id,
    )
    session.add(state)
    await session.flush()
    return state


def _cooldown_for_violations(violation_count: int) -> int:
    if violation_count <= 0:
        return BASE_MESSAGE_INTERVAL_SECONDS
    return COOLDOWN_SECONDS_BY_VIOLATION.get(violation_count, COOLDOWN_SECONDS_BY_VIOLATION[4])


async def _recent_duplicate_in_channel(
    session: AsyncSession,
    *,
    channel_id: UUID,
    sender_id: UUID,
    normalized_body: str,
) -> bool:
    since = datetime.now(UTC) - timedelta(seconds=DUPLICATE_LOOKBACK_SECONDS)
    rows = await session.execute(
        select(MarketplaceCommunityMessage.body)
        .where(
            MarketplaceCommunityMessage.channel_id == channel_id,
            MarketplaceCommunityMessage.sender_id == sender_id,
            MarketplaceCommunityMessage.created_at >= since,
            MarketplaceCommunityMessage.status != MarketplaceMessageStatus.DELETED,
        )
        .order_by(MarketplaceCommunityMessage.created_at.desc())
        .limit(5)
    )
    for (body,) in rows.all():
        if bodies_are_near_duplicates(normalized_body, normalize_body(body)):
            return True
    return False


async def check_message_allowed(
    session: AsyncSession,
    *,
    user_id: UUID,
    marketplace_id: UUID,
    channel_id: UUID,
    body: str,
) -> SpamCheckResult:
    now = datetime.now(UTC)
    state = await get_or_create_spam_state(session, user_id=user_id, marketplace_id=marketplace_id)
    normalized = normalize_body(body)

    if state.muted_until and state.muted_until > now:
        retry = int((state.muted_until - now).total_seconds()) + 1
        return SpamCheckResult(
            allowed=False,
            retry_after_seconds=retry,
            detail=f"You are muted for {retry} seconds due to repeated spam.",
        )

    duplicate = False
    if state.last_normalized_body and bodies_are_near_duplicates(normalized, state.last_normalized_body):
        duplicate = True
    if not duplicate:
        duplicate = await _recent_duplicate_in_channel(
            session,
            channel_id=channel_id,
            sender_id=user_id,
            normalized_body=normalized,
        )

    if duplicate:
        state.violation_count = (state.violation_count or 0) + 1
        if state.violation_count >= 4:
            state.muted_until = now + timedelta(seconds=COOLDOWN_SECONDS_BY_VIOLATION[4])
        state.updated_at = now
        retry = _cooldown_for_violations(state.violation_count)
        return SpamCheckResult(
            allowed=False,
            retry_after_seconds=retry,
            detail=DUPLICATE_MESSAGE,
        )

    cooldown = _cooldown_for_violations(state.violation_count)
    if state.last_message_at is not None:
        elapsed = (now - state.last_message_at).total_seconds()
        if elapsed < cooldown:
            retry = int(cooldown - elapsed) + 1
            return SpamCheckResult(
                allowed=False,
                retry_after_seconds=retry,
                detail=f"Please wait {retry} seconds before sending another message.",
            )

    return SpamCheckResult(allowed=True)


async def record_successful_message(
    session: AsyncSession,
    *,
    user_id: UUID,
    marketplace_id: UUID,
    body: str,
) -> None:
    state = await get_or_create_spam_state(session, user_id=user_id, marketplace_id=marketplace_id)
    state.last_message_at = datetime.now(UTC)
    state.last_normalized_body = normalize_body(body)
    if state.violation_count > 0:
        state.violation_count = max(0, state.violation_count - 1)
    state.updated_at = datetime.now(UTC)


def raise_spam_rejection(result: SpamCheckResult) -> None:
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=result.detail,
        headers={"Retry-After": str(max(result.retry_after_seconds, 1))},
    )
