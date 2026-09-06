"""Admin marketplace and category management."""

from __future__ import annotations

from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin
from app.database import get_db
from app.models import AdminAuditLog, SellerProfile, User
from app.models.marketplace import Marketplace, MarketplaceCategory
from app.routers.marketplaces import _marketplace_out
from app.schemas.marketplace import (
    CategoryReorderRequest,
    MarketplaceCategoryCreate,
    MarketplaceCategoryOut,
    MarketplaceCategoryUpdate,
    MarketplaceCreate,
    MarketplaceListOut,
    MarketplaceOut,
    MarketplaceStatsOut,
    MarketplaceUpdate,
)

router = APIRouter(prefix="/admin/marketplaces", tags=["admin-marketplaces"])


def _escape_ilike(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


async def _get_marketplace(session: AsyncSession, marketplace_id: UUID) -> Marketplace:
    marketplace = await session.get(Marketplace, marketplace_id)
    if marketplace is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marketplace not found")
    return marketplace


async def _get_category(
    session: AsyncSession, marketplace_id: UUID, category_id: UUID
) -> MarketplaceCategory:
    category = await session.scalar(
        select(MarketplaceCategory).where(
            MarketplaceCategory.id == category_id,
            MarketplaceCategory.marketplace_id == marketplace_id,
        )
    )
    if category is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return category


async def _log_action(session: AsyncSession, admin: User, action: str, target_id: str, metadata: dict | None = None) -> None:
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action=action,
            target_type="marketplace",
            target_id=target_id,
            metadata_=metadata or {},
        )
    )


@router.get("", response_model=MarketplaceListOut)
async def admin_list_marketplaces(
    search: str | None = Query(default=None, max_length=120),
    status_filter: str | None = Query(default=None, pattern=r"^(active|hidden|all)$"),
    city: str | None = Query(default=None, max_length=80),
    sort: str = Query(default="display_order", pattern=r"^(display_order|name|created_at|city)$"),
    order: str = Query(default="asc", pattern=r"^(asc|desc)$"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceListOut:
    stmt = select(Marketplace)
    if search:
        pattern = f"%{_escape_ilike(search.strip())}%"
        stmt = stmt.where(
            or_(
                Marketplace.name.ilike(pattern),
                Marketplace.slug.ilike(pattern),
                Marketplace.district.ilike(pattern),
            )
        )
    if city:
        stmt = stmt.where(Marketplace.city.ilike(_escape_ilike(city.strip())))
    if status_filter == "active":
        stmt = stmt.where(Marketplace.is_active.is_(True))
    elif status_filter == "hidden":
        stmt = stmt.where(Marketplace.is_active.is_(False))

    total = int(await session.scalar(select(func.count()).select_from(stmt.subquery())) or 0)
    stats = MarketplaceStatsOut(
        total=int(await session.scalar(select(func.count()).select_from(Marketplace)) or 0),
        active=int(
            await session.scalar(
                select(func.count()).select_from(Marketplace).where(Marketplace.is_active.is_(True))
            )
            or 0
        ),
        hidden=int(
            await session.scalar(
                select(func.count()).select_from(Marketplace).where(Marketplace.is_active.is_(False))
            )
            or 0
        ),
    )

    sort_col = getattr(Marketplace, sort)
    stmt = stmt.order_by(sort_col.desc() if order == "desc" else sort_col.asc())
    offset = (page - 1) * page_size
    rows = list((await session.execute(stmt.offset(offset).limit(page_size))).scalars().all())
    items = [await _marketplace_out(session, row) for row in rows]
    return MarketplaceListOut(items=items, total=total, page=page, page_size=page_size, stats=stats)


@router.post("", response_model=MarketplaceOut, status_code=status.HTTP_201_CREATED)
async def admin_create_marketplace(
    payload: MarketplaceCreate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = Marketplace(id=uuid4(), **payload.model_dump())
    session.add(marketplace)
    try:
        await _log_action(session, admin, "marketplace.create", str(marketplace.id), {"slug": marketplace.slug})
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Slug already exists") from exc
    await session.refresh(marketplace)
    return await _marketplace_out(session, marketplace)


@router.get("/{marketplace_id}", response_model=MarketplaceOut)
async def admin_get_marketplace(
    marketplace_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = await _get_marketplace(session, marketplace_id)
    return await _marketplace_out(session, marketplace)


@router.patch("/{marketplace_id}", response_model=MarketplaceOut)
async def admin_update_marketplace(
    marketplace_id: UUID,
    payload: MarketplaceUpdate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = await _get_marketplace(session, marketplace_id)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(marketplace, key, value)
    try:
        await _log_action(session, admin, "marketplace.update", str(marketplace.id))
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Slug already exists") from exc
    await session.refresh(marketplace)
    return await _marketplace_out(session, marketplace)


@router.delete("/{marketplace_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_marketplace(
    marketplace_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    marketplace = await _get_marketplace(session, marketplace_id)
    await _log_action(session, admin, "marketplace.delete", str(marketplace.id), {"slug": marketplace.slug})
    await session.delete(marketplace)
    await session.commit()


@router.post("/{marketplace_id}/hide", response_model=MarketplaceOut)
async def admin_hide_marketplace(
    marketplace_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = await _get_marketplace(session, marketplace_id)
    marketplace.is_active = False
    await _log_action(session, admin, "marketplace.hide", str(marketplace.id))
    await session.commit()
    await session.refresh(marketplace)
    return await _marketplace_out(session, marketplace)


@router.post("/{marketplace_id}/unhide", response_model=MarketplaceOut)
async def admin_unhide_marketplace(
    marketplace_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceOut:
    marketplace = await _get_marketplace(session, marketplace_id)
    marketplace.is_active = True
    await _log_action(session, admin, "marketplace.unhide", str(marketplace.id))
    await session.commit()
    await session.refresh(marketplace)
    return await _marketplace_out(session, marketplace)


@router.get("/{marketplace_id}/categories", response_model=list[MarketplaceCategoryOut])
async def admin_list_categories(
    marketplace_id: UUID,
    include_hidden: bool = True,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCategoryOut]:
    await _get_marketplace(session, marketplace_id)
    stmt = (
        select(MarketplaceCategory)
        .where(MarketplaceCategory.marketplace_id == marketplace_id)
        .order_by(MarketplaceCategory.display_order, MarketplaceCategory.name)
    )
    if not include_hidden:
        stmt = stmt.where(MarketplaceCategory.is_active.is_(True))
    return list((await session.execute(stmt)).scalars().all())


@router.post(
    "/{marketplace_id}/categories",
    response_model=MarketplaceCategoryOut,
    status_code=status.HTTP_201_CREATED,
)
async def admin_create_category(
    marketplace_id: UUID,
    payload: MarketplaceCategoryCreate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCategoryOut:
    await _get_marketplace(session, marketplace_id)
    if payload.parent_id is not None:
        await _get_category(session, marketplace_id, payload.parent_id)
    category = MarketplaceCategory(id=uuid4(), marketplace_id=marketplace_id, **payload.model_dump())
    session.add(category)
    try:
        await _log_action(
            session,
            admin,
            "marketplace.category.create",
            str(category.id),
            {"marketplace_id": str(marketplace_id), "slug": category.slug},
        )
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category slug already exists") from exc
    await session.refresh(category)
    return category


@router.patch(
    "/{marketplace_id}/categories/{category_id}",
    response_model=MarketplaceCategoryOut,
)
async def admin_update_category(
    marketplace_id: UUID,
    category_id: UUID,
    payload: MarketplaceCategoryUpdate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCategoryOut:
    category = await _get_category(session, marketplace_id, category_id)
    data = payload.model_dump(exclude_unset=True)
    if "parent_id" in data and data["parent_id"] is not None:
        if data["parent_id"] == category_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Category cannot be its own parent")
        await _get_category(session, marketplace_id, data["parent_id"])
    for key, value in data.items():
        setattr(category, key, value)
    try:
        await _log_action(session, admin, "marketplace.category.update", str(category.id))
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category slug already exists") from exc
    await session.refresh(category)
    return category


@router.delete("/{marketplace_id}/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_category(
    marketplace_id: UUID,
    category_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    category = await _get_category(session, marketplace_id, category_id)
    await _log_action(session, admin, "marketplace.category.delete", str(category.id))
    await session.delete(category)
    await session.commit()


@router.post(
    "/{marketplace_id}/categories/{category_id}/hide",
    response_model=MarketplaceCategoryOut,
)
async def admin_hide_category(
    marketplace_id: UUID,
    category_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCategoryOut:
    category = await _get_category(session, marketplace_id, category_id)
    category.is_active = False
    await session.commit()
    await session.refresh(category)
    return category


@router.post(
    "/{marketplace_id}/categories/{category_id}/unhide",
    response_model=MarketplaceCategoryOut,
)
async def admin_unhide_category(
    marketplace_id: UUID,
    category_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCategoryOut:
    category = await _get_category(session, marketplace_id, category_id)
    category.is_active = True
    await session.commit()
    await session.refresh(category)
    return category


@router.post("/{marketplace_id}/categories/reorder", response_model=list[MarketplaceCategoryOut])
async def admin_reorder_categories(
    marketplace_id: UUID,
    payload: CategoryReorderRequest,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCategoryOut]:
    await _get_marketplace(session, marketplace_id)
    result = await session.execute(
        select(MarketplaceCategory).where(MarketplaceCategory.marketplace_id == marketplace_id)
    )
    categories = {row.id: row for row in result.scalars().all()}
    missing = [str(cid) for cid in payload.ordered_ids if cid not in categories]
    if missing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unknown category ids: {', '.join(missing)}")

    for index, category_id in enumerate(payload.ordered_ids):
        categories[category_id].display_order = index
    await _log_action(session, admin, "marketplace.category.reorder", str(marketplace_id))
    await session.commit()
    return sorted(categories.values(), key=lambda c: c.display_order)
