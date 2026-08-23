#!/usr/bin/env python3
"""Expire stale premium flags and subscriptions. Run via cron or manually."""

from __future__ import annotations

import asyncio
import sys

from app.database import SessionLocal
from app.services.premium_maintenance import expire_stale_premium


async def main() -> int:
    async with SessionLocal() as session:
        result = await expire_stale_premium(session)
    print(
        f"Expired {result['users_expired']} user(s) and "
        f"{result['subscriptions_expired']} subscription(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
