"""Schemas for admin-managed platform display advertisements."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.services.platform_advertisements import sanitize_ad_title, validate_ad_url


class AdvertisementPublicOut(BaseModel):
    id: UUID
    title: str
    image_url: str
    target_url: str

    model_config = {"from_attributes": True}


class AdvertisementAdminOut(BaseModel):
    id: UUID
    title: str
    image_url: str
    target_url: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class AdvertisementCreate(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    image_url: str = Field(min_length=8, max_length=2048)
    target_url: str = Field(min_length=8, max_length=2048)
    is_active: bool = True

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str) -> str:
        return sanitize_ad_title(value)

    @field_validator("image_url")
    @classmethod
    def clean_image_url(cls, value: str) -> str:
        return validate_ad_url(value, field_name="image_url")

    @field_validator("target_url")
    @classmethod
    def clean_target_url(cls, value: str) -> str:
        return validate_ad_url(value, field_name="target_url")


class AdvertisementUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=120)
    image_url: str | None = Field(default=None, min_length=8, max_length=2048)
    target_url: str | None = Field(default=None, min_length=8, max_length=2048)
    is_active: bool | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return sanitize_ad_title(value)

    @field_validator("image_url")
    @classmethod
    def clean_image_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_ad_url(value, field_name="image_url")

    @field_validator("target_url")
    @classmethod
    def clean_target_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return validate_ad_url(value, field_name="target_url")
