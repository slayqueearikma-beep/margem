"""Optional: seed marketplace category taxonomy (no users or businesses).

Run manually after migrations if categories table is empty:
  PYTHONPATH=/app python scripts/seed_categories.py
"""

import asyncio

from sqlalchemy import select

from app.data.marketplace_categories import MARKETPLACE_CATEGORIES
from app.database import SessionLocal
from app.models import Category


async def seed_categories() -> None:
    async with SessionLocal() as session:
        existing = await session.execute(select(Category).limit(1))
        if existing.scalar_one_or_none() is not None:
            print("Categories already exist — skipping.")
            return

        for cat in MARKETPLACE_CATEGORIES:
            session.add(
                Category(
                    slug=cat.slug,
                    name_en=cat.name_en,
                    name_fr=cat.name_fr,
                    name_ar=cat.name_ar,
                    icon=cat.icon,
                )
            )

        await session.commit()
        print(f"Seeded {len(MARKETPLACE_CATEGORIES)} categories.")


if __name__ == "__main__":
    asyncio.run(seed_categories())
