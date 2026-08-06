"""Tests for purchase order calculations."""

import pytest

from app.models import Product, ProductDeliveryMode
from app.services.purchase import PurchaseValidationError, calculate_totals


def _product(**kwargs) -> Product:
    base = dict(
        is_purchasable=True,
        is_available=True,
        is_hidden=False,
        is_paused=False,
        price_mad=100.0,
        stock_quantity=5,
        delivery_mode=ProductDeliveryMode.PROVIDER_DELIVERY,
        delivery_fee_mad=25.0,
        free_delivery_threshold_mad=None,
        tax_enabled=False,
    )
    base.update(kwargs)
    product = Product(name="Test", seller_id=__import__("uuid").uuid4())
    for key, value in base.items():
        setattr(product, key, value)
    return product


def test_calculate_totals_pickup_no_delivery_fee():
    product = _product(delivery_mode=ProductDeliveryMode.PICKUP_ONLY)
    totals = calculate_totals(product, quantity=2, delivery_method="pickup")
    assert totals["subtotal_mad"] == 200.0
    assert totals["delivery_fee_mad"] == 0.0
    assert totals["total_mad"] == 200.0


def test_calculate_totals_delivery_with_fee():
    product = _product()
    totals = calculate_totals(product, quantity=1, delivery_method="delivery")
    assert totals["delivery_fee_mad"] == 25.0
    assert totals["total_mad"] == 125.0


def test_calculate_totals_free_delivery_threshold():
    product = _product(free_delivery_threshold_mad=100.0)
    totals = calculate_totals(product, quantity=2, delivery_method="delivery")
    assert totals["subtotal_mad"] == 200.0
    assert totals["delivery_fee_mad"] == 0.0


def test_calculate_totals_rejects_insufficient_stock():
    product = _product(stock_quantity=1)
    with pytest.raises(PurchaseValidationError):
        calculate_totals(product, quantity=2, delivery_method="pickup")


def test_calculate_totals_rejects_non_purchasable():
    product = _product(is_purchasable=False)
    with pytest.raises(PurchaseValidationError):
        calculate_totals(product, quantity=1, delivery_method="pickup")
