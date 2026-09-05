"""Pricing helpers for fixed MAD vs Offre listings."""

from __future__ import annotations

from app.models import PricingType, Product, Service


def normalize_pricing_fields(
    *,
    pricing_type: PricingType | str,
    price_mad: float | None,
) -> tuple[PricingType, float | None, bool]:
    """Return (pricing_type, price_mad, price_negotiable) for persistence."""
    resolved = PricingType(pricing_type)
    if resolved == PricingType.OFFER:
        return resolved, None, True
    if price_mad is None:
        # Legacy listings and minimal create payloads may omit price; treat as Offre.
        return PricingType.OFFER, None, True
    if price_mad < 0:
        raise ValueError("Price must be greater than zero")
    if price_mad == 0:
        return resolved, 0.0, False
    return resolved, float(price_mad), False


def apply_pricing_to_product(product: Product, *, pricing_type: PricingType, price_mad: float | None) -> None:
    product.pricing_type = pricing_type
    product.price_mad = price_mad
    product.price_negotiable = pricing_type == PricingType.OFFER


def apply_pricing_to_service(service: Service, *, pricing_type: PricingType, price_mad: float | None) -> None:
    service.pricing_type = pricing_type
    service.price_mad = price_mad
    service.price_negotiable = pricing_type == PricingType.OFFER


def display_price_label(*, pricing_type: PricingType | str, price_mad: float | None) -> str | None:
    if PricingType(pricing_type) == PricingType.OFFER:
        return "Offre"
    if price_mad is None:
        return None
    return f"{float(price_mad):.2f} MAD"
