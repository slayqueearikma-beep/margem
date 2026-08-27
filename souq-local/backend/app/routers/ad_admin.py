"""Admin CRUD for platform display advertisements."""

from __future__ import annotations

from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin
from app.database import get_db
from app.models import AdminAuditLog, PlatformAdvertisement, User
from app.schemas.advertisements import (
    AdvertisementAdminOut,
    AdvertisementCreate,
    AdvertisementUpdate,
)

router = APIRouter(prefix="/admin/advertisements", tags=["admin-advertisements"])


async def _get_ad(session: AsyncSession, ad_id: UUID) -> PlatformAdvertisement:
    ad = await session.get(PlatformAdvertisement, ad_id)
    if ad is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Advertisement not found")
    return ad


async def _log_action(
    session: AsyncSession,
    admin: User,
    action: str,
    target_id: str,
    metadata: dict | None = None,
) -> None:
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action=action,
            target_type="platform_advertisement",
            target_id=target_id,
            metadata_=metadata or {},
        )
    )


@router.get("", response_model=list[AdvertisementAdminOut])
async def list_advertisements(
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> list[PlatformAdvertisement]:
    result = await session.execute(
        select(PlatformAdvertisement).order_by(PlatformAdvertisement.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("", response_model=AdvertisementAdminOut, status_code=status.HTTP_201_CREATED)
async def create_advertisement(
    payload: AdvertisementCreate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    ad = PlatformAdvertisement(
        id=uuid4(),
        title=payload.title,
        image_url=payload.image_url,
        target_url=payload.target_url,
        is_active=payload.is_active,
    )
    session.add(ad)
    await _log_action(
        session,
        admin,
        "advertisement_created",
        str(ad.id),
        {"title": ad.title, "is_active": ad.is_active},
    )
    await session.commit()
    await session.refresh(ad)
    return ad


@router.patch("/{ad_id}", response_model=AdvertisementAdminOut)
async def update_advertisement(
    ad_id: UUID,
    payload: AdvertisementUpdate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    ad = await _get_ad(session, ad_id)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")
    for key, value in updates.items():
        setattr(ad, key, value)
    await _log_action(
        session,
        admin,
        "advertisement_updated",
        str(ad.id),
        {"fields": sorted(updates.keys())},
    )
    await session.commit()
    await session.refresh(ad)
    return ad


@router.delete("/{ad_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_advertisement(
    ad_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    ad = await _get_ad(session, ad_id)
    await _log_action(session, admin, "advertisement_deleted", str(ad.id), {"title": ad.title})
    await session.delete(ad)
    await session.commit()
