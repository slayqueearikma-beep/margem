"""SQLAlchemy helpers for marketplace search price interval filters."""

from __future__ import annotations

from sqlalchemy import and_, or_

from app.models import PricingType, Product, Service
from app.services.service_pricing import PricingModel

_NO_PRICE_MODELS = {
    PricingModel.REQUEST_QUOTE.value,
    PricingModel.CONTACT_FOR_PRICE.value,
    PricingModel.NEGOTIABLE.value,
}


def product_price_filter(min_price: float | None, max_price: float | None):
    """Return a WHERE clause for fixed-price products, or None when unfiltered."""
    if min_price is None and max_price is None:
        return None

    conditions = [
        Product.pricing_type == PricingType.FIXED,
        Product.price_mad.isnot(None),
    ]
    if min_price is not None:
        conditions.append(Product.price_mad >= min_price)
    if max_price is not None:
        conditions.append(Product.price_mad <= max_price)
    return and_(*conditions)


def service_price_filter(min_price: float | None, max_price: float | None):
    """Return a WHERE clause for priced services, or None when unfiltered."""
    if min_price is None and max_price is None:
        return None

    branches: list = []

    single_price = and_(
        Service.price_mad.isnot(None),
        Service.pricing_model.notin_([PricingModel.PRICE_RANGE.value, *_NO_PRICE_MODELS]),
    )
    single_conditions = [single_price]
    if min_price is not None:
        single_conditions.append(Service.price_mad >= min_price)
    if max_price is not None:
        single_conditions.append(Service.price_mad <= max_price)
    branches.append(and_(*single_conditions))

    range_conditions = [
        Service.pricing_model == PricingModel.PRICE_RANGE.value,
        Service.price_min_mad.isnot(None),
        Service.price_max_mad.isnot(None),
    ]
    if min_price is not None:
        range_conditions.append(Service.price_max_mad >= min_price)
    if max_price is not None:
        range_conditions.append(Service.price_min_mad <= max_price)
    branches.append(and_(*range_conditions))

    free_in_range = (min_price is None or min_price <= 0) and (max_price is None or max_price >= 0)
    if free_in_range:
        branches.append(Service.pricing_model == PricingModel.FREE.value)

    return or_(*branches)
