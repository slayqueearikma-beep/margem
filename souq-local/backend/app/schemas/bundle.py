from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class BundleSlotTemplate(BaseModel):
    key: str = Field(min_length=1, max_length=40)
    label: str = Field(min_length=1, max_length=80)
    category_slug: str = Field(default="", max_length=80)
    query: str = Field(default="", max_length=80)


class BundleTemplateOut(BaseModel):
    slug: str
    name: str
    description: str
    icon: str
    marketplace_slug: str
    slots: list[BundleSlotTemplate]


class BundleResolveSlotIn(BaseModel):
    key: str = Field(min_length=1, max_length=40)
    label: str = Field(min_length=1, max_length=80)
    category_slug: str = Field(default="", max_length=80)
    query: str = Field(default="", max_length=80)


class BundleResolveIn(BaseModel):
    marketplace: str = Field(min_length=1, max_length=80)
    template_slug: str | None = Field(default=None, max_length=80)
    slots: list[BundleResolveSlotIn] = Field(min_length=1, max_length=20)
    min_seller_rating: float = Field(default=0.0, ge=0, le=5)

    @field_validator("slots")
    @classmethod
    def unique_slot_keys(cls, value: list[BundleResolveSlotIn]) -> list[BundleResolveSlotIn]:
        keys = [slot.key for slot in value]
        if len(keys) != len(set(keys)):
            raise ValueError("slot keys must be unique")
        return value


class BundlePickOut(BaseModel):
    slot_key: str
    slot_label: str
    product_id: UUID
    product_name: str
    price_mad: float
    image_url: str
    category_slug: str
    is_available: bool
    stock_quantity: int
    availability_note: str
    warranty_note: str
    seller_id: UUID
    seller_name: str
    seller_verified: bool
    seller_rating: float
    value_score: float
    reference_price_mad: float


class BundleSellerBreakdownOut(BaseModel):
    seller_id: UUID
    seller_name: str
    seller_verified: bool
    seller_rating: float
    subtotal_mad: float
    item_count: int
    warranty_summary: str
    items: list[BundlePickOut]


class BundleResolveOut(BaseModel):
    marketplace: str
    template_slug: str | None = None
    slots_requested: int
    slots_matched: int
    total_price_mad: float
    reference_price_mad: float
    savings_mad: float
    savings_percent: float
    all_available: bool
    picks: list[BundlePickOut]
    missing_slots: list[str]
    seller_breakdown: list[BundleSellerBreakdownOut]
