"""Service pricing model validation and normalization."""

from __future__ import annotations

from enum import Enum

from pydantic import BaseModel, Field, ValidationError, model_validator


class PricingModel(str, Enum):
    FIXED_PRICE = "fixed_price"
    STARTING_FROM = "starting_from"
    PRICE_RANGE = "price_range"
    HOURLY = "hourly"
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    PER_PERSON = "per_person"
    PER_UNIT = "per_unit"
    PER_SQM = "per_sqm"
    PER_KM = "per_km"
    REQUEST_QUOTE = "request_quote"
    CONTACT_FOR_PRICE = "contact_for_price"
    NEGOTIABLE = "negotiable"
    FREE = "free"


_SINGLE_PRICE_MODELS = {
    PricingModel.FIXED_PRICE,
    PricingModel.STARTING_FROM,
    PricingModel.HOURLY,
    PricingModel.DAILY,
    PricingModel.WEEKLY,
    PricingModel.MONTHLY,
    PricingModel.PER_PERSON,
    PricingModel.PER_UNIT,
    PricingModel.PER_SQM,
    PricingModel.PER_KM,
}

_NO_PRICE_MODELS = {
    PricingModel.REQUEST_QUOTE,
    PricingModel.CONTACT_FOR_PRICE,
}


class ServicePricingFields(BaseModel):
    pricing_model: PricingModel = PricingModel.FIXED_PRICE
    price_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_min_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_max_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_negotiable: bool = False

    @model_validator(mode="after")
    def validate_pricing(self) -> ServicePricingFields:
        model = self.pricing_model

        if model in _NO_PRICE_MODELS:
            self.price_mad = None
            self.price_min_mad = None
            self.price_max_mad = None
            self.price_negotiable = False
            return self

        if model == PricingModel.FREE:
            self.price_mad = 0.0
            self.price_min_mad = None
            self.price_max_mad = None
            self.price_negotiable = False
            return self

        if model == PricingModel.NEGOTIABLE:
            self.price_negotiable = True
            self.price_min_mad = None
            self.price_max_mad = None
            return self

        if model == PricingModel.PRICE_RANGE:
            if self.price_min_mad is None or self.price_max_mad is None:
                raise ValueError("Price range requires both minimum and maximum prices")
            if self.price_min_mad > self.price_max_mad:
                raise ValueError("Minimum price cannot exceed maximum price")
            self.price_mad = None
            self.price_negotiable = False
            return self

        if model in _SINGLE_PRICE_MODELS:
            if self.price_mad is None:
                raise ValueError("This pricing model requires a price")
            self.price_min_mad = None
            self.price_max_mad = None
            self.price_negotiable = False
            return self

        return self


def infer_pricing_model(
    *,
    price_mad: float | None,
    price_negotiable: bool,
    pricing_model: str | None = None,
) -> PricingModel:
    if pricing_model:
        return PricingModel(pricing_model)
    if price_negotiable:
        return PricingModel.NEGOTIABLE
    if price_mad is None:
        return PricingModel.REQUEST_QUOTE
    if price_mad == 0:
        return PricingModel.FREE
    return PricingModel.FIXED_PRICE


def normalize_service_pricing(data: dict) -> dict:
    validated = ServicePricingFields.model_validate(data)
    return validated.model_dump()
