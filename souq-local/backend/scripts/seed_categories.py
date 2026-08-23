"""Seed or upsert MarGem business category taxonomy."""

from __future__ import annotations

import asyncio

from sqlalchemy import select

from app.data.business_categories import BUSINESS_CATEGORIES, LEGACY_CATEGORY_SLUGS
from app.database import SessionLocal
from app.models import Category


async def seed_categories() -> None:
    async with SessionLocal() as session:
        for index, legacy_slug in enumerate(LEGACY_CATEGORY_SLUGS, start=900):
            legacy = (
                await session.execute(select(Category).where(Category.slug == legacy_slug))
            ).scalar_one_or_none()
            if legacy is not None:
                legacy.sort_order = index

        upserted = 0
        for cat in BUSINESS_CATEGORIES:
            existing = (
                await session.execute(select(Category).where(Category.slug == cat.slug))
            ).scalar_one_or_none()
            if existing is None:
                session.add(
                    Category(
                        slug=cat.slug,
                        name_en=cat.name_en,
                        name_fr=cat.name_fr,
                        name_ar=cat.name_ar,
                        icon=cat.icon,
                        accent_color=cat.accent_color,
                        sort_order=cat.sort_order,
                    )
                )
                upserted += 1
            else:
                existing.name_en = cat.name_en
                existing.name_fr = cat.name_fr
                existing.name_ar = cat.name_ar
                existing.icon = cat.icon
                existing.accent_color = cat.accent_color
                existing.sort_order = cat.sort_order
                upserted += 1

        await session.commit()
        print(f"Upserted {upserted} business categories.")


if __name__ == "__main__":
    asyncio.run(seed_categories())
