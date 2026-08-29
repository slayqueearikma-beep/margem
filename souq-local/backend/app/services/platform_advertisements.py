"""Manual admin-controlled platform display advertisements."""

from __future__ import annotations

import hashlib
import random
import re
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    AdClick,
    AdImpression,
    Category,
    PlatformAdCampaignStatus,
    PlatformAdPaymentStatus,
    PlatformAdvertisement,
    User,
)
from app.models.marketplace import Marketplace, MarketplaceCategory
from app.services.entitlements import build_entitlements
from app.services.url_security import reject_private_or_internal_url

_HTML_TAG_PATTERN = re.compile(r"<[^>]+>")

AD_PLACEMENTS: tuple[str, ...] = (
    "homepage_top",
    "homepage_middle",
    "homepage_bottom",
    "products_listing",
    "product_detail",
    "seller_profile",
    "service_listing",
    "service_detail",
    "search_results",
    "category_page",
    "city_page",
    "marketplace_page",
)

AD_PLACEMENT_LABELS: dict[str, str] = {
    "homepage_top": "Homepage — top",
    "homepage_middle": "Homepage — middle",
    "homepage_bottom": "Homepage — bottom",
    "products_listing": "Product listing",
    "product_detail": "Product detail",
    "seller_profile": "Seller profile",
    "service_listing": "Service listing",
    "service_detail": "Service detail",
    "search_results": "Search results",
    "category_page": "Category page",
    "city_page": "City page",
    "marketplace_page": "Marketplace page",
}

AD_TARGET_PLATFORMS: tuple[str, ...] = ("all", "web", "mobile")
AD_TARGET_LISTING_TYPES: tuple[str, ...] = ("all", "product", "service")

VALID_STATUS_TRANSITIONS: dict[PlatformAdCampaignStatus, set[PlatformAdCampaignStatus]] = {
    PlatformAdCampaignStatus.DRAFT: {
        PlatformAdCampaignStatus.SCHEDULED,
        PlatformAdCampaignStatus.ACTIVE,
        PlatformAdCampaignStatus.CANCELLED,
    },
    PlatformAdCampaignStatus.SCHEDULED: {
        PlatformAdCampaignStatus.ACTIVE,
        PlatformAdCampaignStatus.PAUSED,
        PlatformAdCampaignStatus.CANCELLED,
    },
    PlatformAdCampaignStatus.ACTIVE: {
        PlatformAdCampaignStatus.PAUSED,
        PlatformAdCampaignStatus.EXPIRED,
        PlatformAdCampaignStatus.COMPLETED,
        PlatformAdCampaignStatus.CANCELLED,
    },
    PlatformAdCampaignStatus.PAUSED: {
        PlatformAdCampaignStatus.ACTIVE,
        PlatformAdCampaignStatus.SCHEDULED,
        PlatformAdCampaignStatus.CANCELLED,
    },
    PlatformAdCampaignStatus.EXPIRED: set(),
    PlatformAdCampaignStatus.COMPLETED: set(),
    PlatformAdCampaignStatus.CANCELLED: set(),
}


def sanitize_ad_title(value: str, *, max_len: int = 120) -> str:
    cleaned = _HTML_TAG_PATTERN.sub("", value.strip())
    if not cleaned:
        raise ValueError("Title is required")
    return cleaned[:max_len]


def validate_ad_url(value: str, *, field_name: str, required: bool = True) -> str | None:
    cleaned = value.strip()
    if not cleaned:
        if required:
            raise ValueError(f"{field_name} is required")
        return None
    return reject_private_or_internal_url(cleaned, field_name=field_name)


def validate_placement(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in AD_PLACEMENTS:
        raise ValueError(f"Invalid placement. Choose one of: {', '.join(AD_PLACEMENTS)}")
    return normalized


def validate_target_platform(value: str) -> str:
    normalized = value.strip().lower()
    if normalized not in AD_TARGET_PLATFORMS:
        raise ValueError(f"Invalid platform. Choose one of: {', '.join(AD_TARGET_PLATFORMS)}")
    return normalized


def validate_target_listing_type(value: str | None) -> str | None:
    if value is None or not value.strip():
        return None
    normalized = value.strip().lower()
    if normalized not in AD_TARGET_LISTING_TYPES:
        raise ValueError(f"Invalid listing type. Choose one of: {', '.join(AD_TARGET_LISTING_TYPES)}")
    return None if normalized == "all" else normalized


def normalize_optional_slug(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip().lower()
    return cleaned or None


def hash_viewer_key(raw: str | None) -> str:
    token = (raw or "anonymous").strip()[:256]
    return hashlib.sha256(token.encode("utf-8")).hexdigest()[:64]


def _utcnow() -> datetime:
    return datetime.now(UTC)


def sync_campaign_status(campaign: PlatformAdvertisement, *, now: datetime | None = None) -> bool:
    """Apply automatic status transitions. Returns True when status changed."""
    if campaign.deleted_at is not None:
        return False
    current = _utcnow() if now is None else now
    previous = campaign.status

    if campaign.status in {
        PlatformAdCampaignStatus.EXPIRED,
        PlatformAdCampaignStatus.COMPLETED,
        PlatformAdCampaignStatus.CANCELLED,
    }:
        campaign.is_active = False
        return False

    if campaign.max_impressions is not None and (campaign.impression_count or 0) >= campaign.max_impressions:
        campaign.status = PlatformAdCampaignStatus.COMPLETED
        campaign.is_active = False
        return campaign.status != previous

    if campaign.ends_at is not None and current > campaign.ends_at:
        campaign.status = PlatformAdCampaignStatus.EXPIRED
        campaign.is_active = False
        return campaign.status != previous

    if campaign.status == PlatformAdCampaignStatus.SCHEDULED:
        if campaign.starts_at is not None and current >= campaign.starts_at and _payment_allows_display(campaign):
            campaign.status = PlatformAdCampaignStatus.ACTIVE
            campaign.is_active = True

    if campaign.status == PlatformAdCampaignStatus.ACTIVE:
        if campaign.starts_at is not None and current < campaign.starts_at:
            campaign.status = PlatformAdCampaignStatus.SCHEDULED
            campaign.is_active = False
        elif not _payment_allows_display(campaign):
            campaign.is_active = False
        else:
            campaign.is_active = True

    return campaign.status != previous


def _payment_allows_display(campaign: PlatformAdvertisement) -> bool:
    return campaign.payment_override or campaign.payment_status == PlatformAdPaymentStatus.PAID


def assert_status_transition(
    current: PlatformAdCampaignStatus,
    desired: PlatformAdCampaignStatus,
) -> None:
    if current == desired:
        return
    allowed = VALID_STATUS_TRANSITIONS.get(current, set())
    if desired not in allowed:
        raise ValueError(f"Cannot transition campaign from {current.value} to {desired.value}")


def _matches_targeting(
    campaign: PlatformAdvertisement,
    *,
    marketplace_slug: str | None,
    city: str | None,
    category_slug: str | None,
    listing_type: str | None,
    platform: str,
) -> bool:
    if campaign.target_marketplace_slug:
        if (
            not marketplace_slug
            or campaign.target_marketplace_slug.lower() != marketplace_slug.strip().lower()
        ):
            return False
    if campaign.target_city:
        if not city or campaign.target_city.lower() != city.strip().lower():
            return False
    if campaign.target_category_slug:
        if not category_slug or campaign.target_category_slug.lower() != category_slug.strip().lower():
            return False
    if campaign.target_listing_type:
        if not listing_type or campaign.target_listing_type.lower() != listing_type.strip().lower():
            return False
    target_platform = (campaign.target_platform or "all").lower()
    if target_platform != "all" and target_platform != platform.lower():
        return False
    return True


async def validate_ad_targeting(
    session: AsyncSession,
    *,
    target_marketplace_slug: str | None,
    target_category_slug: str | None,
) -> None:
    marketplace_slug = normalize_optional_slug(target_marketplace_slug)
    category_slug = normalize_optional_slug(target_category_slug)
    marketplace = None

    if marketplace_slug:
        marketplace = await session.scalar(
            select(Marketplace).where(Marketplace.slug == marketplace_slug, Marketplace.is_active.is_(True))
        )
        if marketplace is None:
            raise ValueError("Target marketplace does not exist or is inactive")

    if category_slug:
        if marketplace is not None:
            category = await session.scalar(
                select(MarketplaceCategory).where(
                    MarketplaceCategory.slug == category_slug,
                    MarketplaceCategory.marketplace_id == marketplace.id,
                    MarketplaceCategory.is_active.is_(True),
                )
            )
            if category is None:
                raise ValueError("Target category does not exist in the selected marketplace")
        else:
            category = await session.scalar(select(Category).where(Category.slug == category_slug))
            if category is None:
                raise ValueError("Target category does not exist")


def _is_eligible_for_display(
    campaign: PlatformAdvertisement,
    *,
    placement: str,
    marketplace_slug: str | None,
    city: str | None,
    category_slug: str | None,
    listing_type: str | None,
    platform: str,
    now: datetime,
) -> bool:
    if campaign.deleted_at is not None:
        return False
    sync_campaign_status(campaign, now=now)
    if campaign.status != PlatformAdCampaignStatus.ACTIVE:
        return False
    if not _payment_allows_display(campaign):
        return False
    if campaign.placement != placement:
        return False
    if campaign.starts_at is not None and now < campaign.starts_at:
        return False
    if campaign.ends_at is not None and now > campaign.ends_at:
        return False
    if campaign.max_impressions is not None and (campaign.impression_count or 0) >= campaign.max_impressions:
        return False
    if not _matches_targeting(
        campaign,
        marketplace_slug=marketplace_slug,
        city=city,
        category_slug=category_slug,
        listing_type=listing_type,
        platform=platform,
    ):
        return False
    return True


async def _passes_user_frequency(
    session: AsyncSession,
    campaign: PlatformAdvertisement,
    *,
    viewer_key: str,
    now: datetime,
) -> bool:
    if campaign.max_impressions_per_user_per_day is not None:
        day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        result = await session.execute(
            select(func.count())
            .select_from(AdImpression)
            .where(
                AdImpression.campaign_id == campaign.id,
                AdImpression.viewer_key == viewer_key,
                AdImpression.recorded_at >= day_start,
            )
        )
        if int(result.scalar_one()) >= campaign.max_impressions_per_user_per_day:
            return False

    if campaign.min_interval_minutes is not None and campaign.min_interval_minutes > 0:
        cutoff = now - timedelta(minutes=campaign.min_interval_minutes)
        result = await session.execute(
            select(AdImpression.recorded_at)
            .where(
                AdImpression.campaign_id == campaign.id,
                AdImpression.viewer_key == viewer_key,
                AdImpression.recorded_at >= cutoff,
            )
            .order_by(AdImpression.recorded_at.desc())
            .limit(1)
        )
        if result.scalar_one_or_none() is not None:
            return False
    return True


def _weighted_choice(campaigns: list[PlatformAdvertisement]) -> PlatformAdvertisement | None:
    if not campaigns:
        return None
    weights = [max(1, campaign.priority) for campaign in campaigns]
    return random.choices(campaigns, weights=weights, k=1)[0]


async def should_show_promotional_ads(session: AsyncSession, user: User | None) -> bool:
    if not settings.ads_enabled:
        return False
    if user is None:
        return True
    bundle = await build_entitlements(session, user)
    return bundle.ads_enabled


async def sync_all_campaign_statuses(session: AsyncSession) -> int:
    result = await session.execute(
        select(PlatformAdvertisement).where(
            PlatformAdvertisement.deleted_at.is_(None),
            PlatformAdvertisement.status.in_(
                [
                    PlatformAdCampaignStatus.SCHEDULED,
                    PlatformAdCampaignStatus.ACTIVE,
                    PlatformAdCampaignStatus.PAUSED,
                ]
            ),
        )
    )
    changed = 0
    for campaign in result.scalars().all():
        if sync_campaign_status(campaign):
            changed += 1
    if changed:
        await session.flush()
    return changed


async def list_active_advertisements(
    session: AsyncSession,
    *,
    user: User | None = None,
    placement: str = "homepage_top",
    marketplace_slug: str | None = None,
    city: str | None = None,
    category_slug: str | None = None,
    listing_type: str | None = None,
    platform: str = "web",
    viewer_key: str | None = None,
    limit: int = 1,
) -> list[PlatformAdvertisement]:
    if not settings.ads_enabled:
        return []
    if not await should_show_promotional_ads(session, user):
        return []
    validated_placement = validate_placement(placement)
    safe_limit = max(1, min(limit, 5))
    hashed_viewer = hash_viewer_key(viewer_key)
    now = _utcnow()

    await sync_all_campaign_statuses(session)

    result = await session.execute(
        select(PlatformAdvertisement)
        .where(
            PlatformAdvertisement.deleted_at.is_(None),
            PlatformAdvertisement.placement == validated_placement,
            PlatformAdvertisement.status.in_(
                [PlatformAdCampaignStatus.ACTIVE, PlatformAdCampaignStatus.SCHEDULED]
            ),
        )
        .order_by(PlatformAdvertisement.priority.desc(), PlatformAdvertisement.created_at.desc())
    )
    candidates = [
        row
        for row in result.scalars().all()
        if _is_eligible_for_display(
            row,
            placement=validated_placement,
            marketplace_slug=marketplace_slug,
            city=city,
            category_slug=category_slug,
            listing_type=listing_type,
            platform=platform,
            now=now,
        )
    ]

    eligible: list[PlatformAdvertisement] = []
    for campaign in candidates:
        if await _passes_user_frequency(session, campaign, viewer_key=hashed_viewer, now=now):
            eligible.append(campaign)

    if not eligible:
        return []

    selected: list[PlatformAdvertisement] = []
    pool = eligible[:]
    while pool and len(selected) < safe_limit:
        pick = _weighted_choice(pool)
        if pick is None:
            break
        selected.append(pick)
        pool = [item for item in pool if item.id != pick.id]
    return selected


async def get_advertisement(session: AsyncSession, ad_id: UUID) -> PlatformAdvertisement | None:
    ad = await session.get(PlatformAdvertisement, ad_id)
    if ad is None or ad.deleted_at is not None:
        return None
    sync_campaign_status(ad)
    return ad


async def record_impression(
    session: AsyncSession,
    *,
    campaign_id: UUID,
    placement: str,
    view_key: str,
    viewer_key: str | None,
    platform: str = "web",
    marketplace_slug: str | None = None,
    city: str | None = None,
    category_slug: str | None = None,
    listing_type: str | None = None,
) -> bool:
    """Record one impression. Returns True when a new impression was stored."""
    if not settings.ads_enabled:
        return False
    if not view_key or len(view_key) > 128:
        raise ValueError("view_key is required")
    campaign = await get_advertisement(session, campaign_id)
    if campaign is None:
        return False
    validated_placement = validate_placement(placement)
    now = _utcnow()
    if not _is_eligible_for_display(
        campaign,
        placement=validated_placement,
        marketplace_slug=marketplace_slug,
        city=city,
        category_slug=category_slug,
        listing_type=listing_type,
        platform=platform,
        now=now,
    ):
        return False

    hashed_viewer = hash_viewer_key(viewer_key)
    if not await _passes_user_frequency(session, campaign, viewer_key=hashed_viewer, now=now):
        return False

    impression = AdImpression(
        id=uuid4(),
        campaign_id=campaign.id,
        viewer_key=hashed_viewer,
        placement=validated_placement,
        platform=platform[:20],
        view_key=view_key[:128],
    )
    try:
        async with session.begin_nested():
            session.add(impression)
            await session.flush()
    except IntegrityError:
        return False

    await session.execute(
        update(PlatformAdvertisement)
        .where(PlatformAdvertisement.id == campaign.id)
        .values(impression_count=PlatformAdvertisement.impression_count + 1)
    )
    await session.refresh(campaign)
    sync_campaign_status(campaign, now=now)
    return True


async def record_click(
    session: AsyncSession,
    *,
    campaign_id: UUID,
    placement: str,
    click_key: str,
    viewer_key: str | None,
    platform: str = "web",
    marketplace_slug: str | None = None,
    city: str | None = None,
    category_slug: str | None = None,
    listing_type: str | None = None,
) -> PlatformAdvertisement | None:
    if not settings.ads_enabled:
        return None
    if not click_key or len(click_key) > 128:
        raise ValueError("click_key is required")
    campaign = await get_advertisement(session, campaign_id)
    if campaign is None:
        return None
    validated_placement = validate_placement(placement)
    now = _utcnow()
    if not _is_eligible_for_display(
        campaign,
        placement=validated_placement,
        marketplace_slug=marketplace_slug,
        city=city,
        category_slug=category_slug,
        listing_type=listing_type,
        platform=platform,
        now=now,
    ):
        return None

    click = AdClick(
        id=uuid4(),
        campaign_id=campaign.id,
        viewer_key=hash_viewer_key(viewer_key),
        placement=validated_placement,
        platform=platform[:20],
        click_key=click_key[:128],
    )
    try:
        async with session.begin_nested():
            session.add(click)
            await session.flush()
    except IntegrityError:
        return campaign

    await session.execute(
        update(PlatformAdvertisement)
        .where(PlatformAdvertisement.id == campaign.id)
        .values(click_count=PlatformAdvertisement.click_count + 1)
    )
    await session.refresh(campaign)
    return campaign


async def get_admin_overview(session: AsyncSession) -> dict[str, int]:
    await sync_all_campaign_statuses(session)
    result = await session.execute(
        select(PlatformAdvertisement).where(PlatformAdvertisement.deleted_at.is_(None))
    )
    campaigns = list(result.scalars().all())
    totals = {
        "active_campaigns": 0,
        "scheduled_campaigns": 0,
        "paused_campaigns": 0,
        "expired_campaigns": 0,
        "completed_campaigns": 0,
        "draft_campaigns": 0,
        "cancelled_campaigns": 0,
        "total_impressions": 0,
        "total_clicks": 0,
    }
    for campaign in campaigns:
        totals["total_impressions"] += campaign.impression_count
        totals["total_clicks"] += campaign.click_count
        key = f"{campaign.status.value}_campaigns"
        if key in totals:
            totals[key] += 1
    return totals


_AD_MEDIA_MAX_BYTES = 12 * 1024 * 1024


def _campaign_allows_public_media(campaign: PlatformAdvertisement, *, now: datetime | None = None) -> bool:
    if campaign.deleted_at is not None:
        return False
    sync_campaign_status(campaign, now=now)
    if campaign.status != PlatformAdCampaignStatus.ACTIVE:
        return False
    return _payment_allows_display(campaign)


async def load_campaign_media_bytes(
    session: AsyncSession,
    *,
    campaign_id: UUID,
    asset_kind: str,
) -> tuple[bytes, str]:
    """Serve ad image/video bytes for CSP-safe same-origin delivery on the public web."""
    if asset_kind not in {"image", "video"}:
        raise ValueError("Invalid ad media asset kind")

    campaign = await get_advertisement(session, campaign_id)
    if campaign is None or not _campaign_allows_public_media(campaign):
        raise LookupError("Advertisement not found")

    source_url = campaign.image_url if asset_kind == "image" else campaign.video_url
    if not source_url:
        raise LookupError("Advertisement asset not found")

    from app.services.media_urls import parse_media_url

    normalized = source_url.strip()
    if normalized.startswith("/media/"):
        normalized = f"{settings.public_api_url.rstrip('/')}{normalized}"

    parsed = parse_media_url(normalized)
    if parsed is not None:
        from app.services.minio_storage import get_object_bytes

        bucket, object_key = parsed
        data, content_type = get_object_bytes(bucket=bucket, object_key=object_key)
        if len(data) > _AD_MEDIA_MAX_BYTES:
            raise ValueError("Advertisement asset too large")
        return data, content_type

    reject_private_or_internal_url(normalized, field_name="asset_url")
    import httpx

    async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
        response = await client.get(normalized)
    if response.status_code != 200:
        raise LookupError("Advertisement asset not found")

    data = response.content
    if len(data) > _AD_MEDIA_MAX_BYTES:
        raise ValueError("Advertisement asset too large")

    content_type = (response.headers.get("content-type") or "").split(";", 1)[0].strip().lower()
    if asset_kind == "image" and not content_type.startswith("image/"):
        raise ValueError("Advertisement image has an invalid content type")
    if asset_kind == "video" and not content_type.startswith("video/"):
        raise ValueError("Advertisement video has an invalid content type")
    if not content_type:
        content_type = "image/jpeg" if asset_kind == "image" else "video/mp4"
    return data, content_type
