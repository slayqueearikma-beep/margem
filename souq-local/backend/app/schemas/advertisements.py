"""Schemas for admin-managed platform display advertisements."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models import PlatformAdCampaignStatus, PlatformAdPaymentStatus
from app.services.platform_advertisements import (
    AD_PLACEMENTS,
    AD_PLACEMENT_LABELS,
    AD_TARGET_LISTING_TYPES,
    AD_TARGET_PLATFORMS,
    sanitize_ad_title,
    validate_ad_url,
    validate_placement,
    validate_target_listing_type,
    validate_target_platform,
)


class PlacementOptionOut(BaseModel):
    value: str
    label: str


class AdvertisementPublicOut(BaseModel):
    id: UUID
    title: str
    description: str | None = None
    image_url: str
    video_url: str | None = None
    target_url: str
    placement: str
    click_url: str

    model_config = {"from_attributes": True}


class AdvertisementAdminOut(BaseModel):
    id: UUID
    advertiser_name: str
    campaign_name: str
    title: str
    description: str | None = None
    image_url: str
    video_url: str | None = None
    target_url: str
    contact_info: str
    placement: str
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: PlatformAdCampaignStatus
    priority: int
    max_impressions: int | None = None
    max_impressions_per_user_per_day: int | None = None
    min_interval_minutes: int | None = None
    impression_count: int
    click_count: int
    payment_status: PlatformAdPaymentStatus
    payment_override: bool
    internal_notes: str
    target_city: str | None = None
    target_marketplace_slug: str | None = None
    target_category_slug: str | None = None
    target_listing_type: str | None = None
    target_platform: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
    created_by_admin_id: UUID | None = None
    remaining_impressions: int | None = None
    ctr_percent: float | None = None

    model_config = {"from_attributes": True}

    @model_validator(mode="before")
    @classmethod
    def enrich_metrics(cls, data):
        if isinstance(data, dict):
            impressions = int(data.get("impression_count") or 0)
            clicks = int(data.get("click_count") or 0)
            max_impressions = data.get("max_impressions")
            data["remaining_impressions"] = (
                max(0, int(max_impressions) - impressions) if max_impressions is not None else None
            )
            data["ctr_percent"] = round((clicks / impressions) * 100, 2) if impressions > 0 else None
            return data
        impressions = int(getattr(data, "impression_count", 0) or 0)
        clicks = int(getattr(data, "click_count", 0) or 0)
        max_impressions = getattr(data, "max_impressions", None)
        setattr(
            data,
            "remaining_impressions",
            max(0, int(max_impressions) - impressions) if max_impressions is not None else None,
        )
        setattr(data, "ctr_percent", round((clicks / impressions) * 100, 2) if impressions > 0 else None)
        return data


class AdvertisementOverviewOut(BaseModel):
    active_campaigns: int
    scheduled_campaigns: int
    paused_campaigns: int
    expired_campaigns: int
    completed_campaigns: int
    draft_campaigns: int
    cancelled_campaigns: int
    total_impressions: int
    total_clicks: int


class AdvertisementCreate(BaseModel):
    advertiser_name: str = Field(min_length=1, max_length=200)
    campaign_name: str = Field(min_length=1, max_length=200)
    title: str = Field(min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    image_url: str = Field(min_length=8, max_length=2048)
    video_url: str | None = Field(default=None, max_length=2048)
    target_url: str = Field(min_length=8, max_length=2048)
    contact_info: str = Field(default="", max_length=500)
    placement: str = Field(default="homepage_top")
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: PlatformAdCampaignStatus = PlatformAdCampaignStatus.DRAFT
    priority: int = Field(default=5, ge=1, le=100)
    max_impressions: int | None = Field(default=None, ge=1)
    max_impressions_per_user_per_day: int | None = Field(default=None, ge=1)
    min_interval_minutes: int | None = Field(default=None, ge=1)
    payment_status: PlatformAdPaymentStatus = PlatformAdPaymentStatus.PENDING
    payment_override: bool = False
    internal_notes: str = Field(default="", max_length=5000)
    target_city: str | None = Field(default=None, max_length=100)
    target_marketplace_slug: str | None = Field(default=None, max_length=80)
    target_category_slug: str | None = Field(default=None, max_length=100)
    target_listing_type: str | None = None
    target_platform: str = "all"

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        return sanitize_ad_title(value)

    @field_validator("placement")
    @classmethod
    def clean_placement(cls, value: str) -> str:
        return validate_placement(value)

    @field_validator("target_platform")
    @classmethod
    def clean_target_platform(cls, value: str) -> str:
        return validate_target_platform(value)

    @field_validator("target_listing_type")
    @classmethod
    def clean_target_listing_type(cls, value: str | None) -> str | None:
        return validate_target_listing_type(value)

    @field_validator("image_url")
    @classmethod
    def clean_image_url(cls, value: str) -> str:
        return validate_ad_url(value, field_name="image_url") or ""

    @field_validator("video_url")
    @classmethod
    def clean_video_url(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        return validate_ad_url(value, field_name="video_url")

    @field_validator("target_url")
    @classmethod
    def clean_target_url(cls, value: str) -> str:
        return validate_ad_url(value, field_name="target_url") or ""

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at")
        return self


class AdvertisementUpdate(BaseModel):
    advertiser_name: str | None = Field(default=None, min_length=1, max_length=200)
    campaign_name: str | None = Field(default=None, min_length=1, max_length=200)
    title: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = Field(default=None, max_length=2000)
    image_url: str | None = Field(default=None, min_length=8, max_length=2048)
    video_url: str | None = Field(default=None, max_length=2048)
    target_url: str | None = Field(default=None, min_length=8, max_length=2048)
    contact_info: str | None = Field(default=None, max_length=500)
    placement: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: PlatformAdCampaignStatus | None = None
    priority: int | None = Field(default=None, ge=1, le=100)
    max_impressions: int | None = Field(default=None, ge=1)
    max_impressions_per_user_per_day: int | None = Field(default=None, ge=1)
    min_interval_minutes: int | None = Field(default=None, ge=1)
    payment_status: PlatformAdPaymentStatus | None = None
    payment_override: bool | None = None
    internal_notes: str | None = Field(default=None, max_length=5000)
    target_city: str | None = Field(default=None, max_length=100)
    target_marketplace_slug: str | None = Field(default=None, max_length=80)
    target_category_slug: str | None = Field(default=None, max_length=100)
    target_listing_type: str | None = None
    target_platform: str | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return sanitize_ad_title(value)

    @field_validator("placement")
    @classmethod
    def clean_placement(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_placement(value)

    @field_validator("target_platform")
    @classmethod
    def clean_target_platform(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_target_platform(value)

    @field_validator("target_listing_type")
    @classmethod
    def clean_target_listing_type(cls, value: str | None) -> str | None:
        return validate_target_listing_type(value)

    @field_validator("image_url")
    @classmethod
    def clean_image_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_ad_url(value, field_name="image_url")

    @field_validator("video_url")
    @classmethod
    def clean_video_url(cls, value: str | None) -> str | None:
        if value is None or not value.strip():
            return None
        return validate_ad_url(value, field_name="video_url")

    @field_validator("target_url")
    @classmethod
    def clean_target_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_ad_url(value, field_name="target_url")


class ImpressionCreate(BaseModel):
    campaign_id: UUID
    placement: str
    view_key: str = Field(min_length=8, max_length=128)
    marketplace_slug: str | None = Field(default=None, max_length=80)
    city: str | None = Field(default=None, max_length=100)
    category_slug: str | None = Field(default=None, max_length=100)
    listing_type: str | None = Field(default=None, max_length=20)

    @field_validator("placement")
    @classmethod
    def clean_placement(cls, value: str) -> str:
        return validate_placement(value)


class ImpressionOut(BaseModel):
    recorded: bool


class AdvertisementPreviewOut(AdvertisementAdminOut):
    placement_label: str


def placement_options() -> list[PlacementOptionOut]:
    return [
        PlacementOptionOut(value=value, label=AD_PLACEMENT_LABELS.get(value, value))
        for value in AD_PLACEMENTS
    ]


def placement_meta() -> dict[str, object]:
    return {
        "placements": placement_options(),
        "statuses": [status.value for status in PlatformAdCampaignStatus],
        "payment_statuses": [status.value for status in PlatformAdPaymentStatus],
        "target_platforms": list(AD_TARGET_PLATFORMS),
        "target_listing_types": list(AD_TARGET_LISTING_TYPES),
    }
