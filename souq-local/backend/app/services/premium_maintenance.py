"""Batch premium and subscription expiry maintenance."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SellerProfile, Subscription, SubscriptionStatus, User


async def expire_stale_premium(session: AsyncSession) -> dict:
    """Clear expired premium flags, mark subscriptions expired, and assign Basic."""
    from app.services.subscription_plans import assign_basic_plan

    now = datetime.now(UTC)

    expired_users = (
        await session.execute(
            select(User).where(
                User.is_premium.is_(True),
                User.premium_until.is_not(None),
                User.premium_until < now,
            )
        )
    ).scalars().all()
    user_ids = [u.id for u in expired_users]
    for user in expired_users:
        user.is_premium = False
        await assign_basic_plan(session, user, provider="system", notify=False)

    if user_ids:
        await session.execute(
            update(SellerProfile)
            .where(SellerProfile.user_id.in_(user_ids))
            .values(is_premium=False)
        )

    subs = await session.execute(
        update(Subscription)
        .where(
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.current_period_end < now,
        )
        .values(status=SubscriptionStatus.EXPIRED)
        .returning(Subscription.id, Subscription.user_id)
    )
    expired_rows = subs.all()
    expired_subs = len(expired_rows)
    for _, user_id in expired_rows:
        user = await session.get(User, user_id)
        if user is not None:
            await assign_basic_plan(session, user, provider="system", notify=False)
    await session.commit()
    return {"users_expired": len(user_ids), "subscriptions_expired": expired_subs}
