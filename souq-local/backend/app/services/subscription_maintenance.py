"""Background subscription expiry maintenance."""

from __future__ import annotations

import logging
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Subscription, SubscriptionStatus, User
from app.services.premium import is_premium_active
from app.services.subscription_service import revoke_expired_entitlements

logger = logging.getLogger("margem.subscription_maintenance")


async def run_subscription_maintenance(session: AsyncSession) -> int:
    """Revoke stale premium flags and mark expired subscriptions. Returns rows touched."""
    now = datetime.now(UTC)
    touched = 0

    expired_subs = (
        await session.execute(
            select(Subscription)
            .options(selectinload(Subscription.plan))
            .where(
                Subscription.status == SubscriptionStatus.ACTIVE,
                Subscription.current_period_end < now,
            )
        )
    ).scalars().all()
    for sub in expired_subs:
        user = await session.get(User, sub.user_id)
        if user is None:
            continue
        await revoke_expired_entitlements(session, user, subscription=sub)
        touched += 1

    premium_users = (
        await session.execute(select(User).where(User.is_premium.is_(True)))
    ).scalars().all()
    for user in premium_users:
        if is_premium_active(
            is_premium=True,
            premium_until=user.premium_until,
            now=now,
        ):
            await revoke_expired_entitlements(session, user)
            continue
        before = user.is_premium
        await revoke_expired_entitlements(session, user)
        if before and not user.is_premium:
            touched += 1

    if touched:
        await session.commit()
    return touched
