"""Tests for subscription plan helpers."""

from app.services.subscription_plans import (
    FREE_PLAN_CODE,
    PLAN_PRICING_MAD,
    is_free_plan,
    plan_grants_premium,
)


class _Plan:
    def __init__(self, code: str, price_mad: float = 0):
        self.code = code
        self.price_mad = price_mad


def test_plan_pricing_constants():
    assert PLAN_PRICING_MAD[FREE_PLAN_CODE] == (0, 0)
    assert PLAN_PRICING_MAD["premium"] == (199, 1999)
    assert PLAN_PRICING_MAD["enterprise"] == (499, 3999)


def test_is_free_plan():
    assert is_free_plan(_Plan("basic")) is True
    assert is_free_plan(_Plan("premium", 199)) is False


def test_plan_grants_premium():
    assert plan_grants_premium(_Plan("basic")) is False
    assert plan_grants_premium(_Plan("premium", 199)) is True
    assert plan_grants_premium(_Plan("enterprise", 499)) is True
