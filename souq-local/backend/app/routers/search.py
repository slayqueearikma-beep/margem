"""Paginated public marketplace search for products, services, and providers."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.data.marketplace_constants import LAUNCH_CITY
from app.database import get_db
from app.limiter import limiter
from app.models import PricingType, Product, SellerProfile, Service, VerificationStatus
from app.schemas import PricingType as PricingTypeSchema
from app.schemas import SellerSummary
from app.services.geo import haversine_km_sql
from app.services.marketplace_scope import resolve_marketplace_id
from app.services.premium import attach_premium_flags, seller_pro_active
from app.services.search_categories import listing_category_filter, resolve_listing_category_slugs

router = APIRouter(prefix="/search", tags=["search"])

_MAX_PAGE_SIZE = 50


def _escaped(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


class ProductSearchOut(BaseModel):
    listing_type: str = "product"
    id: UUID
    seller_id: UUID
    seller_name: str
    seller_city: str
    seller_verified: bool
    seller_premium: bool
    seller_rating: float
    name: str
    description: str
    pricing_type: PricingTypeSchema = PricingTypeSchema.FIXED
    price_mad: float | None
    image_url: str
    category_slug: str
    delivery_available: bool = False
    pickup_only: bool = True
    is_available: bool
    created_at: datetime | None = None


class ServiceSearchOut(BaseModel):
    listing_type: str = "service"
    id: UUID
    seller_id: UUID
    seller_name: str
    seller_city: str
    seller_verified: bool
    seller_premium: bool
    seller_rating: float
    name: str
    description: str
    pricing_type: PricingTypeSchema = PricingTypeSchema.FIXED
    price_mad: float | None
    image_url: str
    category_slug: str
    is_available: bool
    created_at: datetime | None = None


class SearchPage(BaseModel):
    sellers: list[SellerSummary] = Field(default_factory=list)
    products: list[ProductSearchOut] = Field(default_factory=list)
    services: list[ServiceSearchOut] = Field(default_factory=list)
    total_sellers: int = 0
    total_products: int = 0
    total_services: int = 0
    limit: int
    offset: int
    has_more: bool


def _city_filter(city: str | None) -> str:
    cleaned = (city or LAUNCH_CITY).strip()
    return cleaned or LAUNCH_CITY


def _provider_filters(
    stmt,
    *,
    q: str,
    category: str | None,
    min_rating: float | None,
    marketplace_id=None,
    city: str | None = None,
):
    stmt = stmt.where(
        SellerProfile.is_active.is_(True),
        SellerProfile.city.ilike(_escaped(_city_filter(city))),
    )
    if marketplace_id is not None:
        stmt = stmt.where(SellerProfile.marketplace_id == marketplace_id)
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

        slugs = resolve_listing_category_slugs(category)
        if slugs:
            stmt = stmt.join(SellerProfile.categories).where(Category.slug.in_(slugs))
    if min_rating is not None:
        stmt = stmt.where(SellerProfile.average_rating >= min_rating)
    return stmt


def _to_seller_summary(profile: SellerProfile, distance_km: float | None = None) -> SellerSummary:
    attach_premium_flags(profile, persist=False)
    summary = SellerSummary.model_validate(profile)
    if distance_km is None:
        return summary
    return summary.model_copy(update={"distance_km": round(float(distance_km), 2)})


@router.get("", response_model=SearchPage)
@limiter.limit("60/minute")
async def search(
    request: Request,
    q: str = Query(default="", max_length=120),
    mode: str = Query(default="all", pattern="^(all|products|services|providers|sellers)$"),
    category: str | None = Query(default=None, max_length=80),
    marketplace: str | None = Query(default=None, max_length=80),
    city: str | None = Query(default=None, max_length=80),
    min_price: float | None = Query(default=None, ge=0),
    max_price: float | None = Query(default=None, ge=0),
    min_rating: float | None = Query(default=None, ge=0, le=5),
    delivery_available: bool | None = None,
    pickup_only: bool | None = None,
    available_only: bool = True,
    lat: float | None = Query(default=None, ge=-90, le=90),
    lng: float | None = Query(default=None, ge=-180, le=180),
    radius_km: float | None = Query(default=None, ge=0.1, le=500),
    sort: str = Query(
        default="relevance",
        pattern="^(relevance|newest|popular|rating|price_low|price_high|distance)$",
    ),
    limit: int = Query(default=20, ge=1, le=_MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
) -> SearchPage:
    """Search products, services, and providers in Casablanca."""
    q = q.strip()
    if max_price is not None and min_price is not None and max_price < min_price:
        raise HTTPException(status_code=422, detail="max_price must be greater than min_price")

    if (lat is None) ^ (lng is None):
        raise HTTPException(status_code=422, detail="lat and lng must be provided together")
    if sort == "distance" and (lat is None or lng is None):
        raise HTTPException(status_code=422, detail="lat and lng are required when sort=distance")

    has_origin = lat is not None and lng is not None
    marketplace_id = await resolve_marketplace_id(session, marketplace)
    city_name = _city_filter(city)

    if mode == "sellers":
        mode = "providers"

    sellers: list[SellerSummary] = []
    products: list[ProductSearchOut] = []
    services: list[ServiceSearchOut] = []
    total_sellers = total_products = total_services = 0

    if mode in {"all", "providers"}:
        seller_stmt = _provider_filters(
            select(SellerProfile).options(
                selectinload(SellerProfile.categories),
                selectinload(SellerProfile.user),
            ),
            q=q,
            category=category,
            min_rating=min_rating,
            marketplace_id=marketplace_id,
            city=city_name,
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

        total_sellers = int(
            await session.scalar(select(func.count()).select_from(seller_stmt.subquery())) or 0
        )
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
        result = await session.execute(
            seller_stmt.order_by(*seller_order).limit(limit).offset(offset)
        )
        if has_origin:
            for row in result.all():
                profile = row[0]
                distance_km = float(row[1]) if row[1] is not None else None
                sellers.append(_to_seller_summary(profile, distance_km))
        else:
            sellers = [_to_seller_summary(profile) for profile in result.scalars().unique().all()]

    if mode in {"all", "products"}:
        product_stmt = select(Product, SellerProfile).join(
            SellerProfile, Product.seller_id == SellerProfile.id
        ).options(
            selectinload(SellerProfile.user),
        ).where(
            SellerProfile.is_active.is_(True),
            SellerProfile.city.ilike(_escaped(city_name)),
            Product.is_hidden.is_(False),
        )
        if marketplace_id is not None:
            product_stmt = product_stmt.where(SellerProfile.marketplace_id == marketplace_id)
        if available_only:
            product_stmt = product_stmt.where(
                Product.is_available.is_(True), Product.is_paused.is_(False)
            )
        category_filter = listing_category_filter(Product.category_slug, category)
        if category_filter is not None:
            product_stmt = product_stmt.where(category_filter)
        if min_price is not None:
            product_stmt = product_stmt.where(
                Product.pricing_type == PricingType.FIXED, Product.price_mad >= min_price
            )
        if max_price is not None:
            product_stmt = product_stmt.where(
                Product.pricing_type == PricingType.FIXED, Product.price_mad <= max_price
            )
        if min_rating is not None:
            product_stmt = product_stmt.where(SellerProfile.average_rating >= min_rating)
        if delivery_available is True:
            product_stmt = product_stmt.where(Product.delivery_available.is_(True))
        if pickup_only is True:
            product_stmt = product_stmt.where(Product.pickup_only.is_(True))
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
        total_products = int(
            await session.scalar(select(func.count()).select_from(product_stmt.subquery())) or 0
        )
        product_distance_expr = None
        if has_origin:
            product_distance_expr = haversine_km_sql(
                SellerProfile.latitude,
                SellerProfile.longitude,
                lat,
                lng,
            ).label("distance_km")
        if sort == "newest":
            product_order = [Product.created_at.desc()]
        elif sort == "popular":
            product_order = [SellerProfile.favorite_count.desc(), SellerProfile.average_rating.desc()]
        elif sort == "rating":
            product_order = [SellerProfile.average_rating.desc(), SellerProfile.review_count.desc()]
        elif sort == "price_low":
            product_order = [Product.price_mad.asc().nullslast()]
        elif sort == "price_high":
            product_order = [Product.price_mad.desc().nullslast()]
        elif sort == "distance" and product_distance_expr is not None:
            product_order = [product_distance_expr.asc(), Product.created_at.desc()]
        else:
            product_order = [
                prefix_rank.desc() if q else Product.is_featured.desc(),
                SellerProfile.is_premium.desc(),
                SellerProfile.average_rating.desc(),
                Product.created_at.desc(),
            ]
        product_query = product_stmt.order_by(*product_order).limit(limit).offset(offset)
        if product_distance_expr is not None:
            product_query = product_stmt.add_columns(product_distance_expr).order_by(
                *product_order
            ).limit(limit).offset(offset)
            rows = (await session.execute(product_query)).all()
            products = [
                ProductSearchOut(
                    id=p.id,
                    seller_id=s.id,
                    seller_name=s.business_name,
                    seller_city=s.city,
                    seller_verified=s.verification_status == VerificationStatus.VERIFIED,
                    seller_premium=seller_pro_active(s),
                    seller_rating=s.average_rating,
                    name=p.name,
                    description=p.description,
                    pricing_type=p.pricing_type.value,
                    price_mad=float(p.price_mad) if p.price_mad is not None else None,
                    image_url=p.image_url,
                    category_slug=p.category_slug,
                    delivery_available=p.delivery_available,
                    pickup_only=p.pickup_only,
                    is_available=p.is_available and not p.is_paused,
                    created_at=p.created_at,
                )
                for p, s, _distance in rows
            ]
        else:
            rows = (await session.execute(product_query)).all()
            products = [
                ProductSearchOut(
                    id=p.id,
                    seller_id=s.id,
                    seller_name=s.business_name,
                    seller_city=s.city,
                    seller_verified=s.verification_status == VerificationStatus.VERIFIED,
                    seller_premium=seller_pro_active(s),
                    seller_rating=s.average_rating,
                    name=p.name,
                    description=p.description,
                    pricing_type=p.pricing_type.value,
                    price_mad=float(p.price_mad) if p.price_mad is not None else None,
                    image_url=p.image_url,
                    category_slug=p.category_slug,
                    delivery_available=p.delivery_available,
                    pickup_only=p.pickup_only,
                    is_available=p.is_available and not p.is_paused,
                    created_at=p.created_at,
                )
                for p, s in rows
            ]

    if mode in {"all", "services"}:
        service_stmt = select(Service, SellerProfile).join(
            SellerProfile, Service.seller_id == SellerProfile.id
        ).options(
            selectinload(SellerProfile.user),
        ).where(SellerProfile.is_active.is_(True), SellerProfile.city.ilike(_escaped(city_name)))
        if marketplace_id is not None:
            service_stmt = service_stmt.where(SellerProfile.marketplace_id == marketplace_id)
        if available_only:
            service_stmt = service_stmt.where(Service.is_available.is_(True))
        category_filter = listing_category_filter(Service.category_slug, category)
        if category_filter is not None:
            service_stmt = service_stmt.where(category_filter)
        if min_price is not None:
            service_stmt = service_stmt.where(
                Service.pricing_type == PricingType.FIXED, Service.price_mad >= min_price
            )
        if max_price is not None:
            service_stmt = service_stmt.where(
                Service.pricing_type == PricingType.FIXED, Service.price_mad <= max_price
            )
        if min_rating is not None:
            service_stmt = service_stmt.where(SellerProfile.average_rating >= min_rating)
        if q:
            pattern = f"%{_escaped(q)}%"
            service_stmt = service_stmt.where(
                or_(
                    Service.name.ilike(pattern),
                    Service.description.ilike(pattern),
                    Service.category_slug.ilike(pattern),
                    SellerProfile.business_name.ilike(pattern),
                )
            )
        total_services = int(
            await session.scalar(select(func.count()).select_from(service_stmt.subquery())) or 0
        )
        service_distance_expr = None
        if has_origin:
            service_distance_expr = haversine_km_sql(
                SellerProfile.latitude,
                SellerProfile.longitude,
                lat,
                lng,
            ).label("distance_km")
        if sort == "price_low":
            service_order = [Service.price_mad.asc().nullslast()]
        elif sort == "price_high":
            service_order = [Service.price_mad.desc().nullslast()]
        elif sort == "newest":
            service_order = [Service.created_at.desc()]
        elif sort == "distance" and service_distance_expr is not None:
            service_order = [service_distance_expr.asc(), Service.created_at.desc()]
        else:
            service_order = [
                SellerProfile.is_premium.desc(),
                SellerProfile.average_rating.desc(),
                Service.created_at.desc(),
            ]
        service_query = service_stmt.order_by(*service_order).limit(limit).offset(offset)
        if service_distance_expr is not None:
            service_query = service_stmt.add_columns(service_distance_expr).order_by(
                *service_order
            ).limit(limit).offset(offset)
            rows = (await session.execute(service_query)).all()
            services = [
                ServiceSearchOut(
                    id=srv.id,
                    seller_id=s.id,
                    seller_name=s.business_name,
                    seller_city=s.city,
                    seller_verified=s.verification_status == VerificationStatus.VERIFIED,
                    seller_premium=seller_pro_active(s),
                    seller_rating=s.average_rating,
                    name=srv.name,
                    description=srv.description,
                    pricing_type=srv.pricing_type.value,
                    price_mad=float(srv.price_mad) if srv.price_mad is not None else None,
                    image_url=srv.image_url,
                    category_slug=srv.category_slug,
                    is_available=srv.is_available,
                    created_at=srv.created_at,
                )
                for srv, s, _distance in rows
            ]
        else:
            rows = (await session.execute(service_query)).all()
            services = [
                ServiceSearchOut(
                    id=srv.id,
                    seller_id=s.id,
                    seller_name=s.business_name,
                    seller_city=s.city,
                    seller_verified=s.verification_status == VerificationStatus.VERIFIED,
                    seller_premium=seller_pro_active(s),
                    seller_rating=s.average_rating,
                    name=srv.name,
                    description=srv.description,
                    pricing_type=srv.pricing_type.value,
                    price_mad=float(srv.price_mad) if srv.price_mad is not None else None,
                    image_url=srv.image_url,
                    category_slug=srv.category_slug,
                    is_available=srv.is_available,
                    created_at=srv.created_at,
                )
                for srv, s in rows
            ]

    if mode == "products":
        current_total = total_products
    elif mode == "services":
        current_total = total_services
    elif mode == "providers":
        current_total = total_sellers
    else:
        current_total = max(total_products, total_services, total_sellers)

    return SearchPage(
        sellers=sellers,
        products=products,
        services=services,
        total_sellers=total_sellers,
        total_products=total_products,
        total_services=total_services,
        limit=limit,
        offset=offset,
        has_more=offset + limit < current_total,
    )
