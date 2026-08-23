"""Subscription plan codes, pricing constants, and shared helpers."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Subscription, SubscriptionPlan, SubscriptionStatus, User

FREE_PLAN_CODE = "basic"
PREMIUM_PLAN_CODE = "premium"
ENTERPRISE_PLAN_CODE = "enterprise"

PAID_PLAN_CODES = frozenset({PREMIUM_PLAN_CODE, ENTERPRISE_PLAN_CODE})
STRIPE_CHECKOUT_PLAN_CODES = PAID_PLAN_CODES

# Canonical MAD pricing (monthly / yearly).
PLAN_PRICING_MAD: dict[str, tuple[float, float]] = {
    FREE_PLAN_CODE: (0, 0),
    PREMIUM_PLAN_CODE: (199, 1999),
    ENTERPRISE_PLAN_CODE: (499, 3999),
}


def is_free_plan(plan: SubscriptionPlan) -> bool:
    return plan.code == FREE_PLAN_CODE or float(plan.price_mad or 0) <= 0


def plan_grants_premium(plan: SubscriptionPlan) -> bool:
    return plan.code in PAID_PLAN_CODES


def plan_allows_stripe_checkout(plan: SubscriptionPlan) -> bool:
    return plan.code in STRIPE_CHECKOUT_PLAN_CODES


async def get_plan_by_code_optional(session: AsyncSession, plan_code: str) -> SubscriptionPlan | None:
    return (
        await session.execute(
            select(SubscriptionPlan).where(
                SubscriptionPlan.code == plan_code,
                SubscriptionPlan.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()


async def ensure_basic_plan(session: AsyncSession) -> SubscriptionPlan:
    plan = await get_plan_by_code_optional(session, FREE_PLAN_CODE)
    if plan is not None:
        return plan
    from uuid import uuid4

    monthly, yearly = PLAN_PRICING_MAD[FREE_PLAN_CODE]
    plan = SubscriptionPlan(
        id=uuid4(),
        code=FREE_PLAN_CODE,
        name="Basic",
        description="Free forever — list your business and reach local buyers",
        price_mad=monthly,
        price_mad_yearly=yearly,
        billing_period_days=30,
        tier_level=0,
        sort_order=0,
        trial_days=0,
        features=[
            "Business storefront",
            "Product and service listings",
            "Messaging with buyers",
            "Standard search visibility",
        ],
    )
    session.add(plan)
    await session.flush()
    return plan


async def assign_basic_plan(
    session: AsyncSession,
    user: User,
    *,
    provider: str = "system",
    notify: bool = False,
) -> Subscription:
    """Assign the free Basic plan (default for new, expired, or cancelled businesses)."""
    from app.services.subscription_activation import (
        cancel_active_subscriptions,
        sync_user_premium_flags,
        upsert_subscription_record,
    )

    plan = await ensure_basic_plan(session)
    await cancel_active_subscriptions(session, user.id)
    now = datetime.now(UTC)
    subscription = await upsert_subscription_record(
        session,
        user=user,
        plan=plan,
        status=SubscriptionStatus.ACTIVE,
        period_start=now,
        period_end=now + timedelta(days=36500),
        provider=provider,
        provider_reference=f"{provider}-{user.id.hex[:12]}",
        billing_interval="monthly",
        notify=notify,
    )
    await sync_user_premium_flags(session, user, premium_until=None, is_premium=False)
    return subscription
