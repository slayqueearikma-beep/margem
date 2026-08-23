"""Seller category selection limits and validation."""

from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Category

MAX_SELLER_CATEGORIES = 3


def normalize_category_ids(category_ids: list[UUID]) -> list[UUID]:
    """Deduplicate while preserving order."""
    seen: set[UUID] = set()
    normalized: list[UUID] = []
    for category_id in category_ids:
        if category_id in seen:
            continue
        seen.add(category_id)
        normalized.append(category_id)
    return normalized


def validate_category_ids(category_ids: list[UUID]) -> list[UUID]:
    normalized = normalize_category_ids(category_ids)
    if len(normalized) < 1:
        raise ValueError("Select at least one business category")
    if len(normalized) > MAX_SELLER_CATEGORIES:
        raise ValueError(f"Select at most {MAX_SELLER_CATEGORIES} business categories")
    return normalized


async def resolve_seller_categories(
    session: AsyncSession,
    category_ids: list[UUID],
) -> list[Category]:
    normalized = validate_category_ids(category_ids)
    result = await session.execute(select(Category).where(Category.id.in_(normalized)))
    categories = list(result.scalars().all())
    if len(categories) != len(normalized):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more business categories are invalid",
        )
    by_id = {category.id: category for category in categories}
    return [by_id[category_id] for category_id in normalized]
