#!/usr/bin/env python3
"""One-time staff promotion utility.

Usage:
  PYTHONPATH=. python scripts/promote_admin.py --email admin@example.com --role super_admin

Requires DATABASE_URL and a valid JWT_SECRET_KEY in the environment.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

from sqlalchemy import select

from app.database import SessionLocal
from app.models import User, UserRole


async def promote(email: str, role: UserRole) -> None:
    async with SessionLocal() as session:
        result = await session.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user is None:
            raise SystemExit(f"No user found for email: {email}")
        previous = user.role
        user.role = role
        await session.commit()
        print(f"Promoted {email}: {previous.value} -> {role.value}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Promote a MarGem user to staff role")
    parser.add_argument("--email", required=True, help="User email address")
    parser.add_argument(
        "--role",
        default="super_admin",
        choices=[r.value for r in UserRole if r in {UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MODERATOR, UserRole.SUPPORT}],
        help="Staff role to assign",
    )
    args = parser.parse_args()
    asyncio.run(promote(args.email, UserRole(args.role)))


if __name__ == "__main__":
    main()
