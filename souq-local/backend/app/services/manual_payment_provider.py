"""Manual/dev payment provider — activates Dribex services without an external PSP."""

from __future__ import annotations

from uuid import UUID

from app.services.payment_provider import CheckoutSession, PaymentProvider, VerifiedWebhook


class ManualPaymentProvider(PaymentProvider):
    name = "manual"

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
        self.log_event("checkout_created", payment_id=payment_id, service="subscription", plan=plan_code)
        return CheckoutSession(
            payment_id=payment_id,
            checkout_url=None,
            provider=self.name,
            provider_reference=f"manual-sub-{payment_id.hex[:16]}",
            status="success",
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
        self.log_event(
            "checkout_created",
            payment_id=payment_id,
            service="advertising",
            package=package_code,
        )
        return CheckoutSession(
            payment_id=payment_id,
            checkout_url=None,
            provider=self.name,
            provider_reference=f"manual-ad-{payment_id.hex[:16]}",
            status="success",
        )

    def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook:
        raise NotImplementedError("Manual provider does not accept webhooks")


class DisabledPaymentProvider(PaymentProvider):
    name = "none"

    async def create_subscription_checkout(self, **kwargs) -> CheckoutSession:
        raise ValueError("Payment provider is disabled")

    async def create_advertising_checkout(self, **kwargs) -> CheckoutSession:
        raise ValueError("Payment provider is disabled")

    def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook:
        raise NotImplementedError("Payment provider is disabled")
