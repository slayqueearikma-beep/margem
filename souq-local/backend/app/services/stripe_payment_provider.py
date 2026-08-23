"""Optional Stripe Billing integration for Dribex-owned services only.

Stripe Connect, destination charges, transfers, and seller payouts are intentionally
NOT implemented. Verify Stripe availability for a Moroccan entity before production use.
"""

from __future__ import annotations

import json
from uuid import UUID

from app.config import settings
from app.services.payment_provider import CheckoutSession, PaymentProvider, VerifiedWebhook


class StripePaymentProvider(PaymentProvider):
    name = "stripe"

    def __init__(self) -> None:
        if not settings.stripe_secret_key:
            raise ValueError("STRIPE_SECRET_KEY is not configured")

    async def create_subscription_checkout(
        self,
        *,
        payment_id: UUID,
        user_id: UUID,
        plan_code: str,
        amount_mad: float,
        currency: str,
        success_url: str,
        cancel_url: str,
    ) -> CheckoutSession:
        try:
            import stripe
        except ImportError as exc:
            raise ValueError("Stripe SDK is not installed") from exc

        stripe.api_key = settings.stripe_secret_key
        session = stripe.checkout.Session.create(
            mode="payment",
            success_url=success_url,
            cancel_url=cancel_url,
            line_items=[
                {
                    "price_data": {
                        "currency": currency,
                        "product_data": {
                            "name": f"Dribex subscription — {plan_code}",
                            "description": "Platform service fee (not a marketplace product purchase)",
                        },
                        "unit_amount": int(round(amount_mad * 100)),
                    },
                    "quantity": 1,
                }
            ],
            metadata={
                "dribex_payment_id": str(payment_id),
                "dribex_user_id": str(user_id),
                "dribex_service_type": "subscription",
                "dribex_service_code": plan_code,
            },
        )
        self.log_event("checkout_created", payment_id=payment_id, session_id=session.id)
        return CheckoutSession(
            payment_id=payment_id,
            checkout_url=session.url,
            provider=self.name,
            provider_reference=session.id,
            status="pending",
        )

    async def create_advertising_checkout(
        self,
        *,
        payment_id: UUID,
        user_id: UUID,
        package_code: str,
        amount_mad: float,
        currency: str,
        success_url: str,
        cancel_url: str,
        metadata: dict,
    ) -> CheckoutSession:
        try:
            import stripe
        except ImportError as exc:
            raise ValueError("Stripe SDK is not installed") from exc

        stripe.api_key = settings.stripe_secret_key
        session = stripe.checkout.Session.create(
            mode="payment",
            success_url=success_url,
            cancel_url=cancel_url,
            line_items=[
                {
                    "price_data": {
                        "currency": currency,
                        "product_data": {
                            "name": f"Dribex advertising — {package_code}",
                            "description": "Advertising / promotion service fee paid to Dribex",
                        },
                        "unit_amount": int(round(amount_mad * 100)),
                    },
                    "quantity": 1,
                }
            ],
            metadata={
                "dribex_payment_id": str(payment_id),
                "dribex_user_id": str(user_id),
                "dribex_service_type": "advertising",
                "dribex_service_code": package_code,
                **{k: str(v) for k, v in metadata.items() if v is not None},
            },
        )
        self.log_event("checkout_created", payment_id=payment_id, session_id=session.id)
        return CheckoutSession(
            payment_id=payment_id,
            checkout_url=session.url,
            provider=self.name,
            provider_reference=session.id,
            status="pending",
        )

    def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook:
        try:
            import stripe
        except ImportError as exc:
            raise ValueError("Stripe SDK is not installed") from exc

        if not settings.stripe_webhook_secret:
            raise ValueError("STRIPE_WEBHOOK_SECRET is not configured")
        if not signature_header:
            raise ValueError("Missing Stripe signature header")

        event = stripe.Webhook.construct_event(payload, signature_header, settings.stripe_webhook_secret)
        data = event.data.object
        metadata = getattr(data, "metadata", None) or {}
        if isinstance(metadata, dict):
            meta = metadata
        else:
            meta = dict(metadata)

        amount = None
        currency = None
        if hasattr(data, "amount_total") and data.amount_total is not None:
            amount = float(data.amount_total) / 100.0
            currency = getattr(data, "currency", settings.stripe_currency) or settings.stripe_currency

        provider_reference = getattr(data, "id", "") or meta.get("dribex_payment_id", "")
        return VerifiedWebhook(
            event_id=str(event.id),
            event_type=str(event.type),
            provider_reference=str(provider_reference),
            amount_mad=amount,
            currency=currency,
            metadata=meta if isinstance(meta, dict) else json.loads(json.dumps(meta, default=str)),
        )
