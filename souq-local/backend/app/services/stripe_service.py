"""Stripe Checkout integration for product purchases."""

from __future__ import annotations

import logging
from typing import Any

from app.config import settings

logger = logging.getLogger("margem.stripe")

try:
    import stripe
except ImportError:  # pragma: no cover
    stripe = None  # type: ignore


class StripeNotConfiguredError(RuntimeError):
    pass


def _require_stripe():
    if stripe is None:
        raise StripeNotConfiguredError("stripe package is not installed")
    if not settings.stripe_secret_key:
        raise StripeNotConfiguredError("STRIPE_SECRET_KEY is not configured")
    stripe.api_key = settings.stripe_secret_key


def mad_to_stripe_amount(amount_mad: float) -> int:
    """Convert MAD to Stripe minor units (centimes)."""
    return int(round(float(amount_mad) * 100))


def create_checkout_session(
    *,
    order_id: str,
    order_number: str,
    product_name: str,
    quantity: int,
    subtotal_mad: float,
    delivery_fee_mad: float,
    tax_mad: float,
    total_mad: float,
    buyer_email: str,
    success_url: str,
    cancel_url: str,
    metadata: dict[str, str],
) -> dict[str, str]:
    _require_stripe()
    line_items: list[dict[str, Any]] = [
        {
            "price_data": {
                "currency": settings.stripe_currency.lower(),
                "product_data": {"name": product_name},
                "unit_amount": mad_to_stripe_amount(subtotal_mad / quantity if quantity else subtotal_mad),
            },
            "quantity": quantity,
        }
    ]
    if delivery_fee_mad > 0:
        line_items.append(
            {
                "price_data": {
                    "currency": settings.stripe_currency.lower(),
                    "product_data": {"name": "Delivery fee"},
                    "unit_amount": mad_to_stripe_amount(delivery_fee_mad),
                },
                "quantity": 1,
            }
        )
    if tax_mad > 0:
        line_items.append(
            {
                "price_data": {
                    "currency": settings.stripe_currency.lower(),
                    "product_data": {"name": "Tax"},
                    "unit_amount": mad_to_stripe_amount(tax_mad),
                },
                "quantity": 1,
            }
        )

    session = stripe.checkout.Session.create(
        mode="payment",
        customer_email=buyer_email or None,
        line_items=line_items,
        success_url=success_url,
        cancel_url=cancel_url,
        metadata={
            **metadata,
            "order_id": order_id,
            "order_number": order_number,
        },
        payment_intent_data={
            "metadata": {
                "order_id": order_id,
                "order_number": order_number,
            }
        },
    )
    return {"session_id": session.id, "checkout_url": session.url or ""}


def construct_webhook_event(payload: bytes, signature: str):
    _require_stripe()
    if not settings.stripe_webhook_secret:
        raise StripeNotConfiguredError("STRIPE_WEBHOOK_SECRET is not configured")
    return stripe.Webhook.construct_event(payload, signature, settings.stripe_webhook_secret)
