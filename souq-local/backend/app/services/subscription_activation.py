"""Shared subscription activation, premium flag sync, and Stripe status mapping."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import SellerProfile, Subscription, SubscriptionPlan, SubscriptionStatus, User
from app.services.notifications import notify_user
from app.services.subscription_plans import plan_grants_premium
from app.services.premium import is_premium_active

ACTIVE_PREMIUM_STATUSES = {
    SubscriptionStatus.ACTIVE,
    SubscriptionStatus.TRIALING,
}


def stripe_status_to_subscription_status(stripe_status: str) -> SubscriptionStatus:
    mapping = {
        "active": SubscriptionStatus.ACTIVE,
        "trialing": SubscriptionStatus.TRIALING,
        "past_due": SubscriptionStatus.PAST_DUE,
        "canceled": SubscriptionStatus.CANCELED,
        "unpaid": SubscriptionStatus.PAST_DUE,
        "incomplete": SubscriptionStatus.PAST_DUE,
        "incomplete_expired": SubscriptionStatus.EXPIRED,
        "paused": SubscriptionStatus.PAST_DUE,
    }
    return mapping.get(stripe_status, SubscriptionStatus.EXPIRED)


def subscription_grants_premium(status: SubscriptionStatus) -> bool:
    return status in ACTIVE_PREMIUM_STATUSES


async def sync_user_premium_flags(
    session: AsyncSession,
    user: User,
    *,
    premium_until: datetime | None,
    is_premium: bool,
) -> None:
    user.is_premium = is_premium
    user.premium_until = premium_until
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()
    if seller is not None:
        seller.is_premium = is_premium


async def cancel_active_subscriptions(
    session: AsyncSession,
    user_id: UUID,
    *,
    except_stripe_id: str | None = None,
) -> None:
    result = await session.execute(
        select(Subscription).where(
            Subscription.user_id == user_id,
            Subscription.status.in_(list(ACTIVE_PREMIUM_STATUSES)),
        )
    )
    for sub in result.scalars().all():
        if except_stripe_id and sub.stripe_subscription_id == except_stripe_id:
            continue
        sub.status = SubscriptionStatus.CANCELED


async def upsert_subscription_record(
    session: AsyncSession,
    *,
    user: User,
    plan: SubscriptionPlan,
    status: SubscriptionStatus,
    period_start: datetime,
    period_end: datetime,
    provider: str,
    provider_reference: str,
    stripe_subscription_id: str | None = None,
    billing_interval: str = "monthly",
    cancel_at_period_end: bool = False,
    notify: bool = True,
) -> Subscription:
    existing: Subscription | None = None
    if stripe_subscription_id:
        existing = (
            await session.execute(
                select(Subscription).where(Subscription.stripe_subscription_id == stripe_subscription_id)
            )
        ).scalar_one_or_none()

    grants = subscription_grants_premium(status) and plan_grants_premium(plan)
    premium_until = period_end if grants else None

    if existing is not None:
        existing.plan_id = plan.id
        existing.status = status
        existing.current_period_start = period_start
        existing.current_period_end = period_end
        existing.provider = provider
        existing.provider_reference = provider_reference
        existing.billing_interval = billing_interval
        existing.cancel_at_period_end = cancel_at_period_end
        subscription = existing
    else:
        await cancel_active_subscriptions(session, user.id, except_stripe_id=stripe_subscription_id)
        subscription = Subscription(
            id=uuid4(),
            user_id=user.id,
            plan_id=plan.id,
            status=status,
            current_period_start=period_start,
            current_period_end=period_end,
            provider=provider,
            provider_reference=provider_reference,
            stripe_subscription_id=stripe_subscription_id,
            billing_interval=billing_interval,
            cancel_at_period_end=cancel_at_period_end,
        )
        session.add(subscription)

    await sync_user_premium_flags(
        session,
        user,
        premium_until=premium_until,
        is_premium=grants and is_premium_active(is_premium=True, premium_until=premium_until),
    )

    if notify and grants:
        await notify_user(
            session,
            user_id=user.id,
            title="Subscription updated",
            body=f"Your {plan.name} plan is now {status.value}",
            kind="premium",
            data={"plan_code": plan.code, "status": status.value},
        )

    await session.flush()
    return subscription


async def deactivate_user_subscription(
    session: AsyncSession,
    user: User,
    *,
    reason: str = "canceled",
) -> None:
    from app.services.subscription_plans import assign_basic_plan

    result = await session.execute(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status.in_(list(ACTIVE_PREMIUM_STATUSES)),
        )
    )
    for sub in result.scalars().all():
        if sub.status != SubscriptionStatus.CANCELED:
            sub.status = SubscriptionStatus.CANCELED
    await assign_basic_plan(session, user, provider="system", notify=False)
    await notify_user(
        session,
        user_id=user.id,
        title="Subscription ended",
        body=f"Your business subscription has been {reason}.",
        kind="premium",
        data={"reason": reason},
    )


async def get_subscription_out(session: AsyncSession, subscription_id: UUID):
    from app.schemas.billing import SubscriptionOut

    result = await session.execute(
        select(Subscription).options(selectinload(Subscription.plan)).where(Subscription.id == subscription_id)
    )
    subscription = result.scalar_one()
    return SubscriptionOut.from_subscription(subscription)


def utc_from_timestamp(ts: int | None) -> datetime:
    if ts is None:
        return datetime.now(UTC)
    return datetime.fromtimestamp(ts, tz=UTC)
