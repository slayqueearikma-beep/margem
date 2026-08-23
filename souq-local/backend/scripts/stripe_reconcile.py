#!/usr/bin/env python3
"""Reconcile local subscriptions with Stripe (run via cron)."""

from __future__ import annotations

import asyncio

from app.database import SessionLocal
from app.services.stripe_billing import reconcile_stripe_subscriptions


async def main() -> int:
    async with SessionLocal() as session:
        stats = await reconcile_stripe_subscriptions(session)
    print(stats)
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
