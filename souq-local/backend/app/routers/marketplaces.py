"""Public marketplace discovery APIs."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import Category, SellerProfile
from app.models.marketplace import Marketplace, MarketplaceCategory
from app.schemas import SellerSummary
from app.schemas.marketplace import MarketplaceCategoryPublicOut, MarketplaceOut
from app.services.marketplace_scope import resolve_marketplace_id
from app.services.search_categories import resolve_listing_category_slugs
from app.services.seller_marketplace import OTHER_CASABLANCA_MARKETS_SLUG, attach_marketplace_metadata, format_stall_location
from app.data.marketplace_constants import LAUNCH_CITY

router = APIRouter(prefix="/marketplaces", tags=["marketplaces"])


def _escape_ilike(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


async def _marketplace_out(session: AsyncSession, marketplace: Marketplace) -> MarketplaceOut:
    cat_count = int(
        await session.scalar(
            select(func.count())
            .select_from(MarketplaceCategory)
            .where(MarketplaceCategory.marketplace_id == marketplace.id)
        )
        or 0
    )
    seller_count = int(
        await session.scalar(
            select(func.count())
            .select_from(SellerProfile)
            .where(SellerProfile.marketplace_id == marketplace.id, SellerProfile.is_active.is_(True))
        )
        or 0
    )
    return MarketplaceOut(
        id=marketplace.id,
        slug=marketplace.slug,
        name=marketplace.name,
        description=marketplace.description,
        known_for=getattr(marketplace, "known_for", "") or "",
        address=marketplace.address,
        district=marketplace.district,
        city=marketplace.city,
        latitude=marketplace.latitude,
        longitude=marketplace.longitude,
        cover_image_url=marketplace.cover_image_url,
        logo_image_url=marketplace.logo_image_url,
        opening_hours=marketplace.opening_hours or {},
        is_active=marketplace.is_active,
        display_order=marketplace.display_order,
        created_at=marketplace.created_at,
        updated_at=marketplace.updated_at,
        category_count=cat_count,
        seller_count=seller_count,
    )


@router.get("", response_model=list[MarketplaceOut])
async def list_marketplaces(
    city: str | None = Query(default=None, max_length=80),
    active_only: bool = True,
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceOut]:
    stmt = select(Marketplace).order_by(Marketplace.display_order, Marketplace.name)
    if active_only:
        stmt = stmt.where(Marketplace.is_active.is_(True))
    stmt = stmt.where(Marketplace.slug != OTHER_CASABLANCA_MARKETS_SLUG)
    if city:
        stmt = stmt.where(Marketplace.city.ilike(_escape_ilike(city.strip())))
    rows = list((await session.execute(stmt)).scalars().all())
    return [await _marketplace_out(session, row) for row in rows]


@router.get("/{slug}", response_model=MarketplaceOut)
async def get_marketplace(
    slug: str,
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = await session.scalar(select(Marketplace).where(Marketplace.slug == slug))
    if marketplace is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marketplace not found")
    return await _marketplace_out(session, marketplace)


@router.get("/{slug}/categories", response_model=list[MarketplaceCategoryPublicOut])
async def list_marketplace_categories(
    slug: str,
    active_only: bool = True,
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCategoryPublicOut]:
    marketplace = await session.scalar(select(Marketplace).where(Marketplace.slug == slug))
    if marketplace is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marketplace not found")

    stmt = (
        select(MarketplaceCategory)
        .where(MarketplaceCategory.marketplace_id == marketplace.id)
        .order_by(MarketplaceCategory.display_order, MarketplaceCategory.name)
    )
    if active_only:
        stmt = stmt.where(MarketplaceCategory.is_active.is_(True))
    categories = list((await session.execute(stmt)).scalars().all())
    return [MarketplaceCategoryPublicOut.from_category(c) for c in categories]


def _seller_summary_out(seller: SellerProfile) -> SellerSummary:
    attach_marketplace_metadata(seller)
    setattr(seller, "stall_location_summary", format_stall_location(seller))
    setattr(seller, "phone_verified", False)
    return SellerSummary.model_validate(seller)


@router.get("/{slug}/sellers", response_model=list[SellerSummary])
async def list_marketplace_sellers(
    slug: str,
    category: str | None = Query(default=None, max_length=80),
    limit: int = Query(default=24, ge=1, le=100),
    session: AsyncSession = Depends(get_db),
) -> list[SellerSummary]:
    marketplace_id = await resolve_marketplace_id(session, slug)
    stmt = (
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.marketplace),
            selectinload(SellerProfile.user),
        )
        .where(
            SellerProfile.marketplace_id == marketplace_id,
            SellerProfile.is_active.is_(True),
            SellerProfile.city.ilike(LAUNCH_CITY),
        )
        .order_by(SellerProfile.is_premium.desc(), SellerProfile.average_rating.desc())
        .limit(limit)
    )
    if category:
        slugs = resolve_listing_category_slugs(category)
        if slugs:
            stmt = stmt.join(SellerProfile.categories).where(Category.slug.in_(slugs))
    sellers = list((await session.execute(stmt)).scalars().unique().all())
    return [_seller_summary_out(seller) for seller in sellers]


@router.get("/{slug}/featured", response_model=list[SellerSummary])
async def list_marketplace_featured_sellers(
    slug: str,
    limit: int = Query(default=6, ge=1, le=20),
    session: AsyncSession = Depends(get_db),
) -> list[SellerSummary]:
    marketplace_id = await resolve_marketplace_id(session, slug)
    stmt = (
        select(SellerProfile)
        .options(
            selectinload(SellerProfile.categories),
            selectinload(SellerProfile.marketplace),
            selectinload(SellerProfile.user),
        )
        .where(
            SellerProfile.marketplace_id == marketplace_id,
            SellerProfile.is_active.is_(True),
            SellerProfile.is_premium.is_(True),
            SellerProfile.city.ilike(LAUNCH_CITY),
        )
        .order_by(SellerProfile.average_rating.desc(), SellerProfile.review_count.desc())
        .limit(limit)
    )
    sellers = list((await session.execute(stmt)).scalars().all())
    return [_seller_summary_out(seller) for seller in sellers]
