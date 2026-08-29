"""Resolve search filter categories to fundamental listing category slugs."""

from __future__ import annotations

from sqlalchemy import and_, or_, select
from sqlalchemy.sql import ColumnElement

from app.data.marketplace_categories import (
    LEGACY_CATEGORY_SLUG_MAP,
    MARKETPLACE_CATEGORY_SLUGS,
    MARKETPLACE_CATEGORY_TO_FUNDAMENTAL,
)
from app.models import Category, SellerCategory, SellerProfile


def resolve_listing_category_slugs(category: str | None) -> frozenset[str] | None:
    """Map a UI/marketplace category filter to fundamental listing slugs."""
    if category is None:
        return None
    cleaned = category.strip().lower()
    if not cleaned:
        return None

    cleaned = LEGACY_CATEGORY_SLUG_MAP.get(cleaned, cleaned)
    if cleaned in MARKETPLACE_CATEGORY_SLUGS:
        return frozenset({cleaned})

    mapped = MARKETPLACE_CATEGORY_TO_FUNDAMENTAL.get(cleaned)
    if mapped:
        return frozenset({mapped})

    return frozenset({cleaned})


def listing_category_filter(
    category_column,
    category: str | None,
) -> ColumnElement[bool] | None:
    """SQL predicate matching listings by fundamental or seller category."""
    slugs = resolve_listing_category_slugs(category)
    if not slugs:
        return None

    seller_category_exists = (
        select(1)
        .select_from(SellerCategory)
        .join(Category, SellerCategory.category_id == Category.id)
        .where(
            SellerCategory.seller_id == SellerProfile.id,
            Category.slug.in_(slugs),
        )
        .correlate(SellerProfile)
        .exists()
    )

    return or_(
        category_column.in_(slugs),
        and_(category_column == "", seller_category_exists),
    )
