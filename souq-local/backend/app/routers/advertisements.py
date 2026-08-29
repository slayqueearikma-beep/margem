"""Public platform advertisement feed."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, status
from fastapi.responses import RedirectResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_optional
from app.config import settings
from app.database import get_db
from app.models import User
from app.schemas.advertisements import AdvertisementPublicOut, ImpressionCreate, ImpressionOut
from app.services.platform_advertisements import (
    list_active_advertisements,
    load_campaign_media_bytes,
    record_click,
    record_impression,
)

router = APIRouter(prefix="/ads", tags=["advertisements"])


def _public_click_url(campaign_id: UUID, placement: str) -> str:
    return f"/ads/click/{campaign_id}?placement={placement}"


def _to_public_out(ad, *, placement: str) -> AdvertisementPublicOut:
    return AdvertisementPublicOut(
        id=ad.id,
        title=ad.title,
        description=ad.description,
        image_url=ad.image_url,
        video_url=ad.video_url,
        target_url=ad.target_url,
        placement=ad.placement,
        click_url=_public_click_url(ad.id, placement),
    )


@router.get("/active", response_model=list[AdvertisementPublicOut])
async def active_advertisements(
    placement: str = Query(default="homepage_top"),
    city: str | None = Query(default=None, max_length=100),
    category_slug: str | None = Query(default=None, max_length=100),
    listing_type: str | None = Query(default=None, max_length=20),
    platform: str = Query(default="web", max_length=20),
    limit: int = Query(default=1, ge=1, le=5),
    viewer_key: str | None = Header(default=None, alias="X-Ad-Viewer"),
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> list[AdvertisementPublicOut]:
    """Return eligible promotional ads for a placement unless ads are disabled or viewer is ad-free."""
    if not settings.ads_enabled:
        return []
    ads = await list_active_advertisements(
        session,
        user=user,
        placement=placement,
        city=city,
        category_slug=category_slug,
        listing_type=listing_type,
        platform=platform,
        viewer_key=viewer_key,
        limit=limit,
    )
    return [_to_public_out(ad, placement=placement) for ad in ads]


@router.get("/media/{campaign_id}/{asset_kind}", include_in_schema=False)
async def serve_ad_media(
    campaign_id: UUID,
    asset_kind: str,
    session: AsyncSession = Depends(get_db),
) -> Response:
    """Proxy active campaign creatives through the API for CSP-safe public web delivery."""
    if not settings.ads_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    try:
        data, content_type = await load_campaign_media_bytes(
            session,
            campaign_id=campaign_id,
            asset_kind=asset_kind,
        )
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found") from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return Response(
        content=data,
        media_type=content_type,
        headers={
            "Cache-Control": "public, max-age=3600",
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.post("/impressions", response_model=ImpressionOut)
async def register_impression(
    payload: ImpressionCreate,
    platform: str = Query(default="web", max_length=20),
    viewer_key: str | None = Header(default=None, alias="X-Ad-Viewer"),
    session: AsyncSession = Depends(get_db),
) -> ImpressionOut:
    if not settings.ads_enabled:
        return ImpressionOut(recorded=False)
    try:
        recorded = await record_impression(
            session,
            campaign_id=payload.campaign_id,
            placement=payload.placement,
            view_key=payload.view_key,
            viewer_key=viewer_key,
            platform=platform,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    if recorded:
        await session.commit()
    return ImpressionOut(recorded=recorded)


@router.get("/click/{campaign_id}")
async def click_advertisement(
    campaign_id: UUID,
    request: Request,
    placement: str = Query(default="homepage_top"),
    click_key: str | None = Query(default=None, max_length=128),
    platform: str = Query(default="web", max_length=20),
    viewer_key: str | None = Header(default=None, alias="X-Ad-Viewer"),
    session: AsyncSession = Depends(get_db),
) -> RedirectResponse:
    if not settings.ads_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Advertisement not found")
    dedupe_key = click_key or request.headers.get("X-Request-Id") or str(campaign_id)
    campaign = await record_click(
        session,
        campaign_id=campaign_id,
        placement=placement,
        click_key=dedupe_key[:128],
        viewer_key=viewer_key,
        platform=platform,
    )
    await session.commit()
    if campaign is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Advertisement not found")
    return RedirectResponse(url=campaign.target_url, status_code=status.HTTP_302_FOUND)
