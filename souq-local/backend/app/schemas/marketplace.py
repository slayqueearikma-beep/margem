from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class OpeningHoursDay(BaseModel):
    open: str = Field(default="09:00", max_length=8)
    close: str = Field(default="20:00", max_length=8)
    closed: bool = False


class MarketplaceBase(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    slug: str = Field(min_length=1, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    description: str = ""
    known_for: str = ""
    address: str = Field(default="", max_length=255)
    district: str = Field(default="", max_length=120)
    city: str = Field(default="Casablanca", max_length=80)
    latitude: float = Field(default=0.0, ge=-90, le=90)
    longitude: float = Field(default=0.0, ge=-180, le=180)
    cover_image_url: str = Field(default="", max_length=512)
    logo_image_url: str = Field(default="", max_length=512)
    opening_hours: dict = Field(default_factory=dict)
    is_active: bool = True
    display_order: int = Field(default=0, ge=0)


class MarketplaceCreate(MarketplaceBase):
    pass


class MarketplaceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    slug: str | None = Field(default=None, min_length=1, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    description: str | None = None
    known_for: str | None = None
    address: str | None = Field(default=None, max_length=255)
    district: str | None = Field(default=None, max_length=120)
    city: str | None = Field(default=None, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    cover_image_url: str | None = Field(default=None, max_length=512)
    logo_image_url: str | None = Field(default=None, max_length=512)
    opening_hours: dict | None = None
    is_active: bool | None = None
    display_order: int | None = Field(default=None, ge=0)


class MarketplaceOut(MarketplaceBase):
    id: UUID
    created_at: datetime
    updated_at: datetime
    category_count: int = 0
    seller_count: int = 0

    model_config = {"from_attributes": True}


class MarketplaceStatsOut(BaseModel):
    total: int
    active: int
    hidden: int


class MarketplaceListOut(BaseModel):
    items: list[MarketplaceOut]
    total: int
    page: int
    page_size: int
    stats: MarketplaceStatsOut


class MarketplaceCategoryBase(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    slug: str = Field(min_length=1, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    description: str = ""
    icon: str = Field(default="store", max_length=64)
    banner_image_url: str = Field(default="", max_length=512)
    display_order: int = Field(default=0, ge=0)
    is_active: bool = True
    parent_id: UUID | None = None


class MarketplaceCategoryCreate(MarketplaceCategoryBase):
    pass


class MarketplaceCategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    slug: str | None = Field(default=None, min_length=1, max_length=80, pattern=r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
    description: str | None = None
    icon: str | None = Field(default=None, max_length=64)
    banner_image_url: str | None = Field(default=None, max_length=512)
    display_order: int | None = Field(default=None, ge=0)
    is_active: bool | None = None
    parent_id: UUID | None = None


class MarketplaceCategoryOut(MarketplaceCategoryBase):
    id: UUID
    marketplace_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MarketplaceCategoryPublicOut(BaseModel):
    """Mobile-friendly shape aligned with legacy CategoryOut."""

    id: UUID
    slug: str
    name_en: str
    name_fr: str = ""
    name_ar: str = ""
    icon: str
    description: str = ""
    banner_image_url: str = ""
    parent_id: UUID | None = None
    display_order: int = 0

    model_config = {"from_attributes": True}

    @classmethod
    def from_category(cls, category) -> MarketplaceCategoryPublicOut:
        return cls(
            id=category.id,
            slug=category.slug,
            name_en=category.name,
            icon=category.icon,
            description=category.description,
            banner_image_url=category.banner_image_url,
            parent_id=category.parent_id,
            display_order=category.display_order,
        )


class CategoryReorderRequest(BaseModel):
    ordered_ids: list[UUID] = Field(min_length=1)

    @field_validator("ordered_ids")
    @classmethod
    def unique_ids(cls, value: list[UUID]) -> list[UUID]:
        if len(value) != len(set(value)):
            raise ValueError("ordered_ids must be unique")
        return value
