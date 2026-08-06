"""Stripe Checkout for MarGem premium visibility subscriptions."""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

import stripe
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Subscription, SubscriptionPlan, SubscriptionStatus, User

logger = logging.getLogger("margem.billing")


def billing_self_serve_enabled() -> bool:
    if settings.app_env not in {"production", "prod"}:
        return True
    return bool(settings.stripe_secret_key.strip())


def _stripe_client() -> None:
    key = settings.stripe_secret_key.strip()
    if not key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Self-serve premium activation is disabled until a billing provider is configured. "
                "Contact support or use an admin grant."
            ),
        )
    stripe.api_key = key


async def create_checkout_session(
    session: AsyncSession,
    *,
    user: User,
    plan: SubscriptionPlan,
    success_url: str,
    cancel_url: str,
) -> str:
    _stripe_client()
    checkout = await asyncio.to_thread(
        stripe.checkout.Session.create,
        mode="payment",
        customer_email=user.email,
        line_items=[
            {
                "price_data": {
                    "currency": settings.stripe_currency.lower(),
                    "product_data": {
                        "name": plan.name,
                        "description": plan.description or "MarGem Premium",
                    },
                    "unit_amount": int(round(plan.price_mad * 100)),
                },
                "quantity": 1,
            }
        ],
        metadata={
            "user_id": str(user.id),
            "plan_code": plan.code,
        },
        success_url=success_url,
        cancel_url=cancel_url,
    )
    url = checkout.get("url")
    if not url:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Payment provider did not return a checkout URL.",
        )
    logger.info("stripe checkout created user=%s plan=%s", user.id, plan.code)
    return str(url)


async def activate_subscription(
    session: AsyncSession,
    *,
    user_id: UUID,
    plan_code: str,
    provider: str,
    provider_reference: str,
) -> Subscription:
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    result = await session.execute(
        select(SubscriptionPlan).where(
            SubscriptionPlan.code == plan_code,
            SubscriptionPlan.is_active.is_(True),
        )
    )
    plan = result.scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")

    existing = await session.execute(
        select(Subscription).where(
            Subscription.user_id == user.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
    )
    for sub in existing.scalars().all():
        sub.status = SubscriptionStatus.CANCELED

    now = datetime.now(UTC)
    subscription = Subscription(
        id=uuid4(),
        user_id=user.id,
        plan_id=plan.id,
        status=SubscriptionStatus.ACTIVE,
        current_period_start=now,
        current_period_end=now + timedelta(days=plan.billing_period_days),
        provider=provider,
        provider_reference=provider_reference,
    )
    session.add(subscription)
    user.is_premium = True
    user.premium_until = subscription.current_period_end
    await session.flush()
    return subscription


async def fulfill_checkout_session(
    session: AsyncSession,
    *,
    checkout_session_id: str,
    user_id: UUID,
    plan_code: str,
) -> Subscription:
    existing = await session.scalar(
        select(Subscription).where(
            Subscription.provider == "stripe",
            Subscription.provider_reference == checkout_session_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
    )
    if existing is not None:
        return existing

    return await activate_subscription(
        session,
        user_id=user_id,
        plan_code=plan_code,
        provider="stripe",
        provider_reference=checkout_session_id,
    )
