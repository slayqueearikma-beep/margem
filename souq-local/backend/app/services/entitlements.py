"""Authoritative subscription entitlements for Dribex Plus+ and DriverPro."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models import Product, SellerProfile, Service, Subscription, SubscriptionPlan, SubscriptionStatus, User

BUYER_PLUS_PLAN_CODE = settings.buyer_plus_plan_code
DRIVER_PRO_PLAN_CODE = settings.driver_pro_plan_code
SELLER_PLAN_CODES = frozenset({DRIVER_PRO_PLAN_CODE})
BUYER_PLAN_CODES = frozenset({BUYER_PLUS_PLAN_CODE})


def plan_audience(plan_code: str) -> str:
    if plan_code in SELLER_PLAN_CODES or plan_code.startswith("seller"):
        return "seller"
    return "buyer"


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


def subscription_grants_benefits(subscription: Subscription | None, *, now: datetime | None = None) -> bool:
    if subscription is None or subscription.plan is None:
        return False
    if subscription.status != SubscriptionStatus.ACTIVE:
        return False
    clock = now or _utc_now()
    return _aware(subscription.current_period_end) >= clock


async def get_seller_profile(session: AsyncSession, user_id: UUID) -> SellerProfile | None:
    result = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user_id))
    return result.scalar_one_or_none()


async def get_active_subscription_for_audience(
    session: AsyncSession,
    user_id: UUID,
    audience: str,
    *,
    now: datetime | None = None,
) -> Subscription | None:
    clock = now or _utc_now()
    result = await session.execute(
        select(Subscription)
        .join(SubscriptionPlan, Subscription.plan_id == SubscriptionPlan.id)
        .options(selectinload(Subscription.plan))
        .where(
            Subscription.user_id == user_id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.current_period_end >= clock,
        )
        .order_by(Subscription.created_at.desc())
    )
    for sub in result.scalars().all():
        if sub.plan and plan_audience(sub.plan.code) == audience:
            return sub
    return None


async def has_plus_plus(session: AsyncSession, user: User, *, now: datetime | None = None) -> bool:
    sub = await get_active_subscription_for_audience(session, user.id, "buyer", now=now)
    return subscription_grants_benefits(sub, now=now)


async def has_driver_pro(
    session: AsyncSession,
    user: User,
    seller: SellerProfile | None = None,
    *,
    now: datetime | None = None,
) -> bool:
    profile = seller or await get_seller_profile(session, user.id)
    if profile is None:
        return False
    sub = await get_active_subscription_for_audience(session, user.id, "seller", now=now)
    return subscription_grants_benefits(sub, now=now)


async def combined_listing_limit(
    session: AsyncSession,
    user: User,
    seller: SellerProfile,
    *,
    now: datetime | None = None,
) -> int:
    if await has_driver_pro(session, user, seller, now=now):
        return settings.driver_pro_combined_listing_limit
    return settings.free_seller_combined_listing_limit


async def count_combined_listings(session: AsyncSession, seller_id: UUID) -> int:
    product_count = await session.scalar(
        select(func.count(Product.id)).where(Product.seller_id == seller_id)
    )
    service_count = await session.scalar(
        select(func.count(Service.id)).where(Service.seller_id == seller_id)
    )
    return int(product_count or 0) + int(service_count or 0)


async def enforce_combined_listing_limit(
    session: AsyncSession,
    *,
    seller_id: UUID,
    user: User,
) -> None:
    """Row-lock seller and reject creation when combined listing cap is reached."""
    seller = (
        await session.execute(
            select(SellerProfile).where(SellerProfile.id == seller_id).with_for_update()
        )
    ).scalar_one_or_none()
    if seller is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seller not found")

    limit = await combined_listing_limit(session, user, seller)
    count = await count_combined_listings(session, seller_id)
    if count >= limit:
        if limit <= settings.free_seller_combined_listing_limit:
            detail = (
                f"You have reached the free limit of {limit} combined products and services. "
                "Upgrade to DriverPro to create up to 20 combined items."
            )
        else:
            detail = (
                f"You have reached the DriverPro limit of {limit} combined products and services."
            )
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


async def require_driver_pro_for_video(
    session: AsyncSession,
    user: User,
    seller: SellerProfile,
) -> None:
    if not await has_driver_pro(session, user, seller):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="DriverPro subscription is required to upload videos.",
        )


async def sync_entitlement_flags(session: AsyncSession, user: User) -> None:
    """Align legacy premium flags with authoritative subscription records."""
    now = _utc_now()
    buyer_sub = await get_active_subscription_for_audience(session, user.id, "buyer", now=now)
    seller_sub = await get_active_subscription_for_audience(session, user.id, "seller", now=now)

    buyer_active = subscription_grants_benefits(buyer_sub, now=now)
    user.is_premium = buyer_active
    user.premium_until = buyer_sub.current_period_end if buyer_active and buyer_sub else None

    seller = await get_seller_profile(session, user.id)
    if seller is not None:
        seller_active = subscription_grants_benefits(seller_sub, now=now)
        seller.is_premium = seller_active
    await session.flush()


async def revoke_expired_subscriptions(session: AsyncSession, user: User) -> None:
    """Expire subscriptions past period end and sync entitlement flags."""
    now = _utc_now()
    result = await session.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(
            Subscription.user_id == user.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
            Subscription.current_period_end < now,
        )
    )
    for sub in result.scalars().all():
        sub.status = SubscriptionStatus.EXPIRED
    await sync_entitlement_flags(session, user)


async def ensure_plan_purchase_allowed(
    session: AsyncSession,
    user: User,
    plan: SubscriptionPlan,
) -> None:
    audience = plan_audience(plan.code)
    if audience == "seller":
        seller = await get_seller_profile(session, user.id)
        if seller is None:
            raise ValueError("DriverPro requires a seller profile on this account")
    elif audience == "buyer" and plan.code not in BUYER_PLAN_CODES:
        raise ValueError("Unsupported buyer subscription plan")

    existing = await get_active_subscription_for_audience(session, user.id, audience)
    if existing is not None and existing.plan_id == plan.id:
        raise ValueError("You already have an active subscription for this plan")


@dataclass(frozen=True)
class BuyerEntitlementsOut:
    plan_code: str | None
    status: str | None
    plus_plus_active: bool
    show_plus_badge: bool
    promotional_ads_suppressed: bool
    started_at: datetime | None
    expires_at: datetime | None


@dataclass(frozen=True)
class SellerEntitlementsOut:
    plan_code: str | None
    status: str | None
    driver_pro_active: bool
    combined_listing_count: int
    combined_listing_limit: int
    combined_listing_remaining: int
    video_uploads_enabled: bool
    started_at: datetime | None
    expires_at: datetime | None


@dataclass(frozen=True)
class EntitlementsBundle:
    buyer: BuyerEntitlementsOut
    seller: SellerEntitlementsOut | None


async def build_entitlements(
    session: AsyncSession,
    user: User,
    *,
    seller: SellerProfile | None = None,
) -> EntitlementsBundle:
    await revoke_expired_subscriptions(session, user)
    now = _utc_now()
    buyer_sub = await get_active_subscription_for_audience(session, user.id, "buyer", now=now)
    buyer_active = subscription_grants_benefits(buyer_sub, now=now)
    buyer = BuyerEntitlementsOut(
        plan_code=buyer_sub.plan.code if buyer_sub and buyer_sub.plan else None,
        status=buyer_sub.status.value if buyer_sub else None,
        plus_plus_active=buyer_active,
        show_plus_badge=buyer_active,
        promotional_ads_suppressed=buyer_active,
        started_at=buyer_sub.current_period_start if buyer_sub else None,
        expires_at=buyer_sub.current_period_end if buyer_sub else None,
    )

    profile = seller or await get_seller_profile(session, user.id)
    seller_out: SellerEntitlementsOut | None = None
    if profile is not None:
        seller_sub = await get_active_subscription_for_audience(session, user.id, "seller", now=now)
        driver_active = subscription_grants_benefits(seller_sub, now=now)
        count = await count_combined_listings(session, profile.id)
        limit = await combined_listing_limit(session, user, profile, now=now)
        seller_out = SellerEntitlementsOut(
            plan_code=seller_sub.plan.code if seller_sub and seller_sub.plan else None,
            status=seller_sub.status.value if seller_sub else None,
            driver_pro_active=driver_active,
            combined_listing_count=count,
            combined_listing_limit=limit,
            combined_listing_remaining=max(0, limit - count),
            video_uploads_enabled=driver_active,
            started_at=seller_sub.current_period_start if seller_sub else None,
            expires_at=seller_sub.current_period_end if seller_sub else None,
        )

    return EntitlementsBundle(buyer=buyer, seller=seller_out)
