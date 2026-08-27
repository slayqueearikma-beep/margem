"""Subscription helpers — authoritative plan eligibility and expiry."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Subscription, SubscriptionPlan, User
from app.services.entitlements import (
    BUYER_PLUS_PLAN_CODE,
    DRIVER_PRO_PLAN_CODE,
    SELLER_PLAN_CODES,
    ensure_plan_purchase_allowed,
    get_active_subscription_for_audience,
    has_plus_plus,
    plan_audience,
    revoke_expired_subscriptions,
    sync_entitlement_flags,
)

__all__ = [
    "BUYER_PLUS_PLAN_CODE",
    "DRIVER_PRO_PLAN_CODE",
    "SELLER_PLAN_CODES",
    "ensure_checkout_allowed",
    "get_active_subscription",
    "plan_audience",
    "revoke_expired_entitlements",
    "user_has_buyer_premium",
]


async def get_active_subscription(
    session: AsyncSession,
    user_id: UUID,
) -> Subscription | None:
    """Most recently active subscription of any audience (buyer preferred for legacy callers)."""
    buyer = await get_active_subscription_for_audience(session, user_id, "buyer")
    if buyer is not None:
        return buyer
    return await get_active_subscription_for_audience(session, user_id, "seller")


async def revoke_expired_entitlements(
    session: AsyncSession,
    user: User,
    *,
    subscription: Subscription | None = None,
) -> Subscription | None:
    await revoke_expired_subscriptions(session, user)
    if subscription is not None and subscription.status.value == "expired":
        return None
    buyer = await get_active_subscription_for_audience(session, user.id, "buyer")
    if buyer is not None:
        return buyer
    return await get_active_subscription_for_audience(session, user.id, "seller")


async def user_has_buyer_premium(session: AsyncSession, user: User) -> bool:
    await revoke_expired_subscriptions(session, user)
    return await has_plus_plus(session, user)


async def ensure_checkout_allowed(
    session: AsyncSession,
    user: User,
    plan: SubscriptionPlan,
) -> None:
    await ensure_plan_purchase_allowed(session, user, plan)
