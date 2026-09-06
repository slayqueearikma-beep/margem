"""Geography API schemas."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field


class CountryOut(BaseModel):
    id: UUID
    code: str
    name_en: str
    name_ar: str
    name_fr: str
    is_active: bool

    model_config = {"from_attributes": True}


class CityOut(BaseModel):
    id: UUID
    slug: str
    name_en: str
    name_ar: str
    name_fr: str
    region: str
    latitude: float
    longitude: float
    is_active: bool
    sort_order: int
    country: CountryOut

    model_config = {"from_attributes": True}


class CityListResponse(BaseModel):
    items: list[CityOut] = Field(default_factory=list)
