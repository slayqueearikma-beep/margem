#!/usr/bin/env python3
"""Sync Stripe Price IDs from environment variables into subscription_plans."""

from __future__ import annotations

import asyncio
import os
import sys

from sqlalchemy import select

from app.database import SessionLocal
from app.models import SubscriptionPlan

PLAN_ENV_KEYS = {
    "vip": ("STRIPE_VIP_PRICE_MONTHLY", "STRIPE_VIP_PRICE_YEARLY"),
    "premium": ("STRIPE_PREMIUM_PRICE_MONTHLY", "STRIPE_PREMIUM_PRICE_YEARLY"),
    "enterprise": ("STRIPE_ENTERPRISE_PRICE_MONTHLY", "STRIPE_ENTERPRISE_PRICE_YEARLY"),
}


async def main() -> int:
    updates: dict[str, tuple[str, str]] = {}
    for code, (monthly_key, yearly_key) in PLAN_ENV_KEYS.items():
        monthly = os.environ.get(monthly_key, "").strip()
        yearly = os.environ.get(yearly_key, "").strip()
        if monthly or yearly:
            updates[code] = (monthly, yearly)

    if not updates:
        print("No STRIPE_*_PRICE_* env vars set — nothing to sync", file=sys.stderr)
        return 1

    async with SessionLocal() as session:
        for code, (monthly, yearly) in updates.items():
            plan = (
                await session.execute(select(SubscriptionPlan).where(SubscriptionPlan.code == code))
            ).scalar_one_or_none()
            if plan is None:
                print(f"Plan not found: {code}", file=sys.stderr)
                continue
            if monthly:
                plan.stripe_price_id_monthly = monthly
            if yearly:
                plan.stripe_price_id_yearly = yearly
            print(f"Updated {code}: monthly={plan.stripe_price_id_monthly!r} yearly={plan.stripe_price_id_yearly!r}")
        await session.commit()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
