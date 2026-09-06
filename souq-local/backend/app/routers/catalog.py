from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import Category, Product, SellerProfile, Service, VerificationStatus, WarningZone
from app.schemas import CategoryOut, ProductOut, ServiceOut, WarningZoneOut
from app.services.search_categories import listing_category_filter

router = APIRouter(tags=["catalog"])

_MAX_PAGE_SIZE = 50


def _escape_ilike(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _public_product_visible(product: Product) -> bool:
    return (
        not bool(getattr(product, "is_hidden", False))
        and bool(getattr(product, "is_available", True))
        and not bool(getattr(product, "is_paused", False))
    )


class SellerContextOut(BaseModel):
    id: UUID
    business_name: str
    city: str
    verified: bool
    premium: bool
    average_rating: float
    review_count: int
    verification_status: str


class ProductPublicOut(BaseModel):
    product: ProductOut
    seller: SellerContextOut


class ServicePublicOut(BaseModel):
    service: ServiceOut
    seller: SellerContextOut


class ServiceListItem(BaseModel):
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
    price_negotiable: bool = False
    image_url: str
    category_slug: str
    is_available: bool


class ServiceListPage(BaseModel):
    items: list[ServiceListItem] = Field(default_factory=list)
    total: int = 0
    limit: int
    offset: int
    has_more: bool


def _seller_context(seller: SellerProfile) -> SellerContextOut:
    status_value = seller.verification_status
    if hasattr(status_value, "value"):
        status_value = status_value.value
    return SellerContextOut(
        id=seller.id,
        business_name=seller.business_name,
        city=seller.city,
        verified=seller.verification_status == VerificationStatus.VERIFIED,
        premium=bool(seller.is_premium),
        average_rating=seller.average_rating,
        review_count=seller.review_count,
        verification_status=str(status_value),
    )


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(session: AsyncSession = Depends(get_db)) -> list[Category]:
    result = await session.execute(select(Category).order_by(Category.name_en))
    return list(result.scalars().all())


@router.get("/warning-zones", response_model=list[WarningZoneOut])
async def list_warning_zones(
    city: str | None = None,
    session: AsyncSession = Depends(get_db),
) -> list[WarningZone]:
    stmt = select(WarningZone).where(WarningZone.is_active.is_(True))
    if city:
        stmt = stmt.where(WarningZone.city.ilike(_escape_ilike(city[:80])))
    result = await session.execute(stmt)
    return list(result.scalars().all())


@router.get("/products/{product_id}", response_model=ProductPublicOut)
async def get_public_product(
    product_id: UUID,
    session: AsyncSession = Depends(get_db),
) -> ProductPublicOut:
    row = (
        await session.execute(
            select(Product, SellerProfile)
            .join(SellerProfile, Product.seller_id == SellerProfile.id)
            .where(Product.id == product_id)
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product, seller = row
    if not seller.is_active or not _public_product_visible(product):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return ProductPublicOut(product=ProductOut.model_validate(product), seller=_seller_context(seller))


@router.get("/services", response_model=ServiceListPage)
async def list_public_services(
    q: str = Query(default="", max_length=120),
    city: str | None = Query(default=None, max_length=80),
    category: str | None = Query(default=None, max_length=80),
    available_only: bool = True,
    limit: int = Query(default=20, ge=1, le=_MAX_PAGE_SIZE),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db),
) -> ServiceListPage:
    stmt = (
        select(Service, SellerProfile)
        .join(SellerProfile, Service.seller_id == SellerProfile.id)
        .where(SellerProfile.is_active.is_(True))
    )
    if available_only:
        stmt = stmt.where(Service.is_available.is_(True))
    if city:
        stmt = stmt.where(SellerProfile.city.ilike(_escape_ilike(city[:80])))
    category_filter = listing_category_filter(Service.category_slug, category)
    if category_filter is not None:
        stmt = stmt.where(category_filter)
    q = q.strip()
    if q:
        pattern = f"%{_escape_ilike(q)}%"
        stmt = stmt.where(
            or_(
                Service.name.ilike(pattern),
                Service.description.ilike(pattern),
                SellerProfile.business_name.ilike(pattern),
            )
        )
    total = int(await session.scalar(select(func.count()).select_from(stmt.subquery())) or 0)
    rows = (
        await session.execute(
            stmt.order_by(
                SellerProfile.is_premium.desc(),
                SellerProfile.average_rating.desc(),
                Service.created_at.desc(),
            )
            .limit(limit)
            .offset(offset)
        )
    ).all()
    items = [
        ServiceListItem(
            id=service.id,
            seller_id=seller.id,
            seller_name=seller.business_name,
            seller_city=seller.city,
            seller_verified=seller.verification_status == VerificationStatus.VERIFIED,
            seller_premium=bool(seller.is_premium),
            seller_rating=seller.average_rating,
            name=service.name,
            description=service.description,
            price_mad=float(service.price_mad) if service.price_mad is not None else None,
            price_negotiable=bool(getattr(service, "price_negotiable", False)),
            image_url=service.image_url,
            category_slug=getattr(service, "category_slug", "") or "",
            is_available=service.is_available,
        )
        for service, seller in rows
    ]
    return ServiceListPage(
        items=items,
        total=total,
        limit=limit,
        offset=offset,
        has_more=offset + limit < total,
    )


@router.get("/services/{service_id}", response_model=ServicePublicOut)
async def get_public_service(
    service_id: UUID,
    session: AsyncSession = Depends(get_db),
) -> ServicePublicOut:
    row = (
        await session.execute(
            select(Service, SellerProfile)
            .join(SellerProfile, Service.seller_id == SellerProfile.id)
            .options(selectinload(SellerProfile.categories))
            .where(Service.id == service_id)
        )
    ).one_or_none()
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    service, seller = row
    if not seller.is_active or not service.is_available:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")
    return ServicePublicOut(service=ServiceOut.model_validate(service), seller=_seller_context(seller))
