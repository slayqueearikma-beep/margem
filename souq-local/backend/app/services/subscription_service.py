"""Subscription helpers — authoritative plan eligibility and expiry."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import SellerProfile, Subscription, SubscriptionPlan, SubscriptionStatus, User
from app.services.premium import is_premium_active

SELLER_PLAN_CODES = frozenset({"seller_pro"})


def plan_audience(plan_code: str) -> str:
    if plan_code in SELLER_PLAN_CODES or plan_code.startswith("seller"):
        return "seller"
    return "buyer"


async def get_active_subscription(
    session: AsyncSession,
    user_id: UUID,
) -> Subscription | None:
    result = await session.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def revoke_expired_entitlements(
    session: AsyncSession,
    user: User,
    *,
    subscription: Subscription | None = None,
) -> Subscription | None:
    """Return the active subscription or revoke stale premium flags."""
    sub = subscription or await get_active_subscription(session, user.id)
    if sub is None:
        if user.is_premium and not is_premium_active(
            is_premium=user.is_premium,
            premium_until=user.premium_until,
        ):
            user.is_premium = False
            user.premium_until = None
            seller = (
                await session.execute(
                    select(SellerProfile).where(SellerProfile.user_id == user.id)
                )
            ).scalar_one_or_none()
            if seller is not None:
                seller.is_premium = False
            await session.flush()
        return None

    period_end = sub.current_period_end
    if period_end.tzinfo is None:
        period_end = period_end.replace(tzinfo=UTC)
    now = datetime.now(UTC)
    if period_end < now:
        sub.status = SubscriptionStatus.EXPIRED
        user.is_premium = False
        user.premium_until = None
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
        ).scalar_one_or_none()
        if seller is not None:
            seller.is_premium = False
        await session.flush()
        return None

    user.is_premium = True
    user.premium_until = period_end
    return sub


async def user_has_buyer_premium(session: AsyncSession, user: User) -> bool:
    """True when the user holds an active Dribex Plus (buyer) subscription."""
    sub = await revoke_expired_entitlements(session, user)
    if sub is None or sub.plan is None:
        return False
    return plan_audience(sub.plan.code) == "buyer"


async def ensure_checkout_allowed(
    session: AsyncSession,
    user: User,
    plan: SubscriptionPlan,
) -> None:
    """Reject checkout when the user already holds the same active plan."""
    sub = await revoke_expired_entitlements(session, user)
    if sub is None:
        return
    if sub.plan_id == plan.id or sub.plan.code == plan.code:
        raise ValueError("You already have an active subscription for this plan")
