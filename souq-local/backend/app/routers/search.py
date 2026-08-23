"""Paginated public marketplace search for products and storefronts."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.limiter import limiter
from app.models import Product, SellerProfile, VerificationStatus
from app.schemas import SellerSummary
from app.services.geo import haversine_km_sql

router = APIRouter(prefix="/search", tags=["search"])

_MAX_PAGE_SIZE = 50


def _escaped(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


class ProductSearchOut(BaseModel):
    id: UUID
    seller_id: UUID
    seller_name: str
    seller_city: str
    seller_verified: bool
    seller_premium: bool
    seller_rating: float
    name: str
    description: str
    price_mad: float | None
    price_negotiable: bool
    image_url: str
    category_slug: str
    is_available: bool
    created_at: datetime | None = None
    distance_km: float | None = None


class SearchPage(BaseModel):
    sellers: list[SellerSummary] = Field(default_factory=list)
    products: list[ProductSearchOut] = Field(default_factory=list)
    total_sellers: int = 0
    total_products: int = 0
    limit: int
    offset: int
    has_more: bool


class SearchSuggestions(BaseModel):
    sellers: list[dict] = Field(default_factory=list)
    products: list[dict] = Field(default_factory=list)
    categories: list[str] = Field(default_factory=list)


def _seller_filters(
    stmt,
    *,
    q: str,
    city: str | None,
    category: str | None,
    verified_only: bool,
    premium_only: bool,
    min_rating: float | None,
):
    stmt = stmt.where(SellerProfile.is_active.is_(True))
    if city:
        stmt = stmt.where(SellerProfile.city.ilike(_escaped(city[:80])))
    if q:
        pattern = f"%{_escaped(q[:120])}%"
        stmt = stmt.where(
            or_(
                SellerProfile.business_name.ilike(pattern),
                SellerProfile.description.ilike(pattern),
            )
        )
    if category:
        from app.models import Category

        stmt = stmt.join(SellerProfile.categories).where(Category.slug == category[:80])
    if verified_only:
        stmt = stmt.where(SellerProfile.verification_status == VerificationStatus.VERIFIED)
    if premium_only:
        stmt = stmt.where(SellerProfile.is_premium.is_(True))
    if min_rating is not None:
        stmt = stmt.where(SellerProfile.average_rating >= min_rating)
    return stmt


def _to_seller_summary(profile: SellerProfile, distance_km: float | None = None) -> SellerSummary:
    summary = SellerSummary.model_validate(profile)
    if distance_km is None:
        return summary
    return summary.model_copy(update={"distance_km": round(float(distance_km), 2)})


@router.get("", response_model=SearchPage)
@limiter.limit("60/minute")
async def search(
    request: Request,
    q: str = Query(default="", max_length=120),
    mode: str = Query(default="all", pattern="^(all|products|sellers)$"),
    city: str | None = Query(default=None, max_length=80),
    category: str | None = Query(default=None, max_length=80),
    min_price: float | None = Query(default=None, ge=0),
    max_price: float | None = Query(default=None, ge=0),
    min_rating: float | None = Query(default=None, ge=0, le=5),
    verified_only: bool = False,
    premium_only: bool = False,
    available_only: bool = True,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius_km: float | None = Query(default=None, ge=0.1, le=200),
    sort: str = Query(
        default="relevance",
        pattern="^(relevance|newest|popular|rating|price_low|price_high|distance)$",
    ),
    limit: int = Query(default=20, ge=1, le=_MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
) -> SearchPage:
    """Search storefronts and products with stable pagination and safe filters."""
    q = q.strip()
    if max_price is not None and min_price is not None and max_price < min_price:
        raise HTTPException(status_code=422, detail="max_price must be greater than min_price")
    if (lat is None) ^ (lng is None):
        raise HTTPException(status_code=422, detail="lat and lng must be provided together")
    if sort == "distance" and (lat is None or lng is None):
        raise HTTPException(
            status_code=422,
            detail="lat and lng are required when sort=distance",
        )

    has_origin = lat is not None and lng is not None
    sellers: list[SellerSummary] = []
    products: list[ProductSearchOut] = []
    total_sellers = total_products = 0

    if mode in {"all", "sellers"}:
        seller_stmt = _seller_filters(
            select(SellerProfile).options(selectinload(SellerProfile.categories)),
            q=q,
            city=city,
            category=category,
            verified_only=verified_only,
            premium_only=premium_only,
            min_rating=min_rating,
        )
        total_sellers = int(
            await session.scalar(select(func.count()).select_from(seller_stmt.subquery())) or 0
        )
        distance_expr = None
        if has_origin:
            distance_expr = haversine_km_sql(
                SellerProfile.latitude,
                SellerProfile.longitude,
                lat,
                lng,
            ).label("distance_km")
            seller_stmt = seller_stmt.add_columns(distance_expr)
            if radius_km is not None:
                seller_stmt = seller_stmt.where(distance_expr <= radius_km)

        if sort == "distance" and distance_expr is not None:
            seller_order = [distance_expr.asc(), SellerProfile.average_rating.desc()]
        else:
            seller_order = [
                SellerProfile.is_premium.desc(),
                SellerProfile.verification_status.desc(),
                SellerProfile.average_rating.desc(),
                SellerProfile.review_count.desc(),
                SellerProfile.created_at.desc(),
            ]

        seller_rows = (
            await session.execute(
                seller_stmt.order_by(*seller_order).limit(limit).offset(offset)
            )
        ).all()

        if has_origin:
            for row in seller_rows:
                profile = row[0]
                distance_km = float(row[1]) if row[1] is not None else None
                sellers.append(_to_seller_summary(profile, distance_km))
        else:
            sellers = [_to_seller_summary(row[0]) for row in seller_rows]

    if mode in {"all", "products"}:
        product_stmt = select(Product, SellerProfile).join(
            SellerProfile, Product.seller_id == SellerProfile.id
        ).where(SellerProfile.is_active.is_(True), Product.is_hidden.is_(False))
        if available_only:
            product_stmt = product_stmt.where(
                Product.is_available.is_(True), Product.is_paused.is_(False)
            )
        if city:
            product_stmt = product_stmt.where(SellerProfile.city.ilike(_escaped(city[:80])))
        if category:
            product_stmt = product_stmt.where(Product.category_slug == category[:80])
        if min_price is not None:
            product_stmt = product_stmt.where(Product.price_mad >= min_price)
        if max_price is not None:
            product_stmt = product_stmt.where(Product.price_mad <= max_price)
        if min_rating is not None:
            product_stmt = product_stmt.where(SellerProfile.average_rating >= min_rating)
        if verified_only:
            product_stmt = product_stmt.where(
                SellerProfile.verification_status == VerificationStatus.VERIFIED
            )
        if premium_only:
            product_stmt = product_stmt.where(SellerProfile.is_premium.is_(True))
        prefix_rank = 0
        if q:
            pattern = f"%{_escaped(q)}%"
            product_stmt = product_stmt.where(
                or_(
                    Product.name.ilike(pattern),
                    Product.description.ilike(pattern),
                    Product.category_slug.ilike(pattern),
                    SellerProfile.business_name.ilike(pattern),
                )
            )
            prefix_rank = case((Product.name.ilike(f"{_escaped(q)}%"), 1), else_=0)
        distance_expr = None
        if has_origin:
            distance_expr = haversine_km_sql(
                SellerProfile.latitude,
                SellerProfile.longitude,
                lat,
                lng,
            ).label("distance_km")
            product_stmt = product_stmt.add_columns(distance_expr)
            if radius_km is not None:
                product_stmt = product_stmt.where(distance_expr <= radius_km)

        total_products = int(
            await session.scalar(select(func.count()).select_from(product_stmt.subquery())) or 0
        )
        if sort == "distance" and distance_expr is not None:
            product_order = [distance_expr.asc(), SellerProfile.average_rating.desc()]
        elif sort == "newest":
            product_order = [Product.created_at.desc()]
        elif sort == "popular":
            product_order = [SellerProfile.favorite_count.desc(), SellerProfile.average_rating.desc()]
        elif sort == "rating":
            product_order = [SellerProfile.average_rating.desc(), SellerProfile.review_count.desc()]
        elif sort == "price_low":
            product_order = [Product.price_mad.asc().nullslast()]
        elif sort == "price_high":
            product_order = [Product.price_mad.desc().nullslast()]
        else:
            product_order = [
                prefix_rank.desc() if q else Product.is_featured.desc(),
                SellerProfile.is_premium.desc(),
                SellerProfile.average_rating.desc(),
                Product.created_at.desc(),
            ]
        rows = (
            await session.execute(product_stmt.order_by(*product_order).limit(limit).offset(offset))
        ).all()
        for row in rows:
            if has_origin:
                p, s, distance_km = row[0], row[1], row[2]
            else:
                p, s = row[0], row[1]
                distance_km = None
            products.append(
                ProductSearchOut(
                    id=p.id,
                    seller_id=s.id,
                    seller_name=s.business_name,
                    seller_city=s.city,
                    seller_verified=s.verification_status == VerificationStatus.VERIFIED,
                    seller_premium=s.is_premium,
                    seller_rating=s.average_rating,
                    name=p.name,
                    description=p.description,
                    price_mad=p.price_mad,
                    price_negotiable=p.price_negotiable,
                    image_url=p.image_url,
                    category_slug=p.category_slug,
                    is_available=p.is_available and not p.is_paused,
                    created_at=p.created_at,
                    distance_km=round(float(distance_km), 2) if distance_km is not None else None,
                )
            )

    current_total = total_products if mode == "products" else total_sellers if mode == "sellers" else max(total_products, total_sellers)
    return SearchPage(
        sellers=sellers,
        products=products,
        total_sellers=total_sellers,
        total_products=total_products,
        limit=limit,
        offset=offset,
        has_more=offset + limit < current_total,
    )
