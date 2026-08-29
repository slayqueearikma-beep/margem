"""Authoritative Dribex Plus+ / DriverPro catalog — overrides stale DB rows."""

from __future__ import annotations

from typing import Any
from uuid import uuid4

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SubscriptionPlan

BUYER_PLUS_CATALOG: dict[str, Any] = {
    "name": "Dribex Plus+",
    "price_mad": 50,
    "billing_period_days": 30,
    "description": "Buyer subscription — suppress promotional ads and show Plus+ badge.",
    "features": [
        "promotional_ads_suppressed",
        "plus_plus_badge",
        "saved_searches_sync",
        "priority_support",
    ],
}

DRIVER_PRO_CATALOG: dict[str, Any] = {
    "name": "DriverPro",
    "price_mad": 149,
    "billing_period_days": 30,
    "description": (
        "Seller subscription — ad-free access, up to 20 combined products/services, and video uploads."
    ),
    "features": [
        "promotional_ads_suppressed",
        "combined_listing_limit_20",
        "video_uploads",
        "featured_placement",
        "premium_badge",
    ],
}

CATALOG_BY_CODE: dict[str, dict[str, Any]] = {
    "buyer_premium": BUYER_PLUS_CATALOG,
    "seller_pro": DRIVER_PRO_CATALOG,
}


def catalog_for_code(plan_code: str) -> dict[str, Any] | None:
    return CATALOG_BY_CODE.get(plan_code)


def apply_catalog_to_plan(plan: SubscriptionPlan) -> SubscriptionPlan:
    """Return the plan with authoritative marketing fields for known codes."""
    meta = catalog_for_code(plan.code)
    if meta is None:
        return plan
    plan.name = meta["name"]
    plan.price_mad = meta["price_mad"]
    plan.billing_period_days = meta.get("billing_period_days", plan.billing_period_days)
    plan.description = meta["description"]
    plan.features = list(meta["features"])
    return plan


async def ensure_subscription_plans_seeded(session: AsyncSession) -> None:
    """Insert default plans when the table is empty (fresh environments)."""
    existing = await session.execute(select(SubscriptionPlan).limit(1))
    if existing.scalar_one_or_none() is not None:
        return
    session.add_all(
        [
            SubscriptionPlan(id=uuid4(), code="buyer_premium", is_active=True, **BUYER_PLUS_CATALOG),
            SubscriptionPlan(id=uuid4(), code="seller_pro", is_active=True, **DRIVER_PRO_CATALOG),
        ]
    )
    await session.commit()


async def sync_subscription_plans_catalog(session: AsyncSession) -> None:
    """Persist authoritative plan pricing/features (fixes legacy 99 MAD / old feature rows)."""
    for code, meta in CATALOG_BY_CODE.items():
        await session.execute(
            update(SubscriptionPlan).where(SubscriptionPlan.code == code).values(**meta)
        )
    await session.commit()
