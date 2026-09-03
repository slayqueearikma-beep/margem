"""Admin CRUD for platform display advertisements."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin
from app.database import get_db
from app.models import (
    AdminAuditLog,
    PlatformAdCampaignStatus,
    PlatformAdPaymentStatus,
    PlatformAdvertisement,
    User,
)
from app.schemas.advertisements import (
    AdvertisementAdminOut,
    AdvertisementCreate,
    AdvertisementOverviewOut,
    AdvertisementPreviewOut,
    AdvertisementUpdate,
    placement_meta,
)
from app.services.platform_advertisements import (
    AD_PLACEMENT_LABELS,
    assert_status_transition,
    get_admin_overview,
    get_advertisement,
    sync_campaign_status,
)

router = APIRouter(prefix="/admin/advertisements", tags=["admin-advertisements"])


async def _get_ad(session: AsyncSession, ad_id: UUID) -> PlatformAdvertisement:
    ad = await session.get(PlatformAdvertisement, ad_id)
    if ad is None or ad.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Advertisement not found")
    sync_campaign_status(ad)
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


def _apply_status_side_effects(ad: PlatformAdvertisement, status_value: PlatformAdCampaignStatus) -> None:
    if status_value == PlatformAdCampaignStatus.ACTIVE:
        if not ad.payment_override and ad.payment_status != PlatformAdPaymentStatus.PAID:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Campaign cannot be activated until payment status is PAID or payment override is enabled",
            )
        ad.is_active = True
    elif status_value in {
        PlatformAdCampaignStatus.PAUSED,
        PlatformAdCampaignStatus.DRAFT,
        PlatformAdCampaignStatus.CANCELLED,
        PlatformAdCampaignStatus.EXPIRED,
        PlatformAdCampaignStatus.COMPLETED,
    }:
        ad.is_active = False
    elif status_value == PlatformAdCampaignStatus.SCHEDULED:
        ad.is_active = False


@router.get("/meta")
async def advertisement_meta(admin: User = Depends(require_admin)) -> dict[str, object]:
    return placement_meta()


@router.get("/overview", response_model=AdvertisementOverviewOut)
async def advertisement_overview(
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> AdvertisementOverviewOut:
    stats = await get_admin_overview(session)
    await session.commit()
    return AdvertisementOverviewOut(**stats)


@router.get("", response_model=list[AdvertisementAdminOut])
async def list_advertisements(
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> list[PlatformAdvertisement]:
    result = await session.execute(
        select(PlatformAdvertisement)
        .where(PlatformAdvertisement.deleted_at.is_(None))
        .order_by(PlatformAdvertisement.created_at.desc())
    )
    rows = list(result.scalars().all())
    for row in rows:
        sync_campaign_status(row)
    await session.commit()
    return rows


@router.get("/{ad_id}", response_model=AdvertisementAdminOut)
async def get_advertisement_detail(
    ad_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    return await _get_ad(session, ad_id)


@router.get("/{ad_id}/preview", response_model=AdvertisementPreviewOut)
async def preview_advertisement(
    ad_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> AdvertisementPreviewOut:
    ad = await _get_ad(session, ad_id)
    payload = AdvertisementAdminOut.model_validate(ad).model_dump()
    payload["placement_label"] = AD_PLACEMENT_LABELS.get(ad.placement, ad.placement)
    return AdvertisementPreviewOut(**payload)


@router.post("", response_model=AdvertisementAdminOut, status_code=status.HTTP_201_CREATED)
async def create_advertisement(
    payload: AdvertisementCreate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    ad = PlatformAdvertisement(
        id=uuid4(),
        advertiser_name=payload.advertiser_name.strip(),
        campaign_name=payload.campaign_name.strip(),
        title=payload.title,
        description=payload.description,
        image_url=payload.image_url,
        video_url=payload.video_url,
        target_url=payload.target_url,
        contact_info=payload.contact_info.strip(),
        placement=payload.placement,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        status=payload.status,
        priority=payload.priority,
        max_impressions=payload.max_impressions,
        max_impressions_per_user_per_day=payload.max_impressions_per_user_per_day,
        min_interval_minutes=payload.min_interval_minutes,
        payment_status=payload.payment_status,
        payment_override=payload.payment_override,
        internal_notes=payload.internal_notes.strip(),
        target_city=(payload.target_city or "").strip().lower() or None,
        target_category_slug=(payload.target_category_slug or "").strip().lower() or None,
        target_listing_type=payload.target_listing_type,
        target_platform=payload.target_platform,
        created_by_admin_id=admin.id,
        is_active=payload.status == PlatformAdCampaignStatus.ACTIVE,
    )
    sync_campaign_status(ad)
    session.add(ad)
    await _log_action(
        session,
        admin,
        "advertisement_created",
        str(ad.id),
        {"campaign_name": ad.campaign_name, "status": ad.status.value},
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

    if "status" in updates:
        desired = updates["status"]
        try:
            assert_status_transition(ad.status, desired)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        _apply_status_side_effects(ad, desired)

    for key, value in updates.items():
        if key == "target_city":
            value = (value or "").strip().lower() or None
        elif key == "target_category_slug":
            value = (value or "").strip().lower() or None
        elif key in {"advertiser_name", "campaign_name", "contact_info", "internal_notes"} and isinstance(value, str):
            value = value.strip()
        setattr(ad, key, value)

    if ad.starts_at and ad.ends_at and ad.ends_at <= ad.starts_at:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="ends_at must be after starts_at")

    sync_campaign_status(ad)
    ad.updated_at = datetime.now(UTC)
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


@router.post("/{ad_id}/pause", response_model=AdvertisementAdminOut)
async def pause_advertisement(
    ad_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    ad = await _get_ad(session, ad_id)
    try:
        assert_status_transition(ad.status, PlatformAdCampaignStatus.PAUSED)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    ad.status = PlatformAdCampaignStatus.PAUSED
    ad.is_active = False
    await _log_action(session, admin, "advertisement_paused", str(ad.id))
    await session.commit()
    await session.refresh(ad)
    return ad


@router.post("/{ad_id}/resume", response_model=AdvertisementAdminOut)
async def resume_advertisement(
    ad_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> PlatformAdvertisement:
    ad = await _get_ad(session, ad_id)
    if not ad.payment_override and ad.payment_status != PlatformAdPaymentStatus.PAID:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot resume until payment status is PAID or payment override is enabled",
        )
    try:
        assert_status_transition(ad.status, PlatformAdCampaignStatus.ACTIVE)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    ad.status = PlatformAdCampaignStatus.ACTIVE
    sync_campaign_status(ad)
    await _log_action(session, admin, "advertisement_resumed", str(ad.id))
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
    ad.deleted_at = datetime.now(UTC)
    ad.status = PlatformAdCampaignStatus.CANCELLED
    ad.is_active = False
    await _log_action(session, admin, "advertisement_deleted", str(ad.id), {"campaign_name": ad.campaign_name})
    await session.commit()
