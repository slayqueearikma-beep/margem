"""NAPS payment provider — sole production PSP for Dribex service revenue."""

from __future__ import annotations

from decimal import Decimal
from uuid import UUID

from app.config import settings
from app.services.naps_client import NapsClient, NapsIntegrationNotConfiguredError
from app.services.payment_provider import CheckoutSession, PaymentProvider, VerifiedWebhook


class NapsPaymentProvider(PaymentProvider):
    name = "naps"

    def __init__(self) -> None:
        self._client = NapsClient()

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
        return await self._create_checkout(
            payment_id=payment_id,
            user_id=user_id,
            service_type="subscription",
            service_code=plan_code,
            amount_mad=amount_mad,
            currency=currency,
            success_url=success_url,
            cancel_url=cancel_url,
            description=f"Dribex Premium — {plan_code}",
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
        return await self._create_checkout(
            payment_id=payment_id,
            user_id=user_id,
            service_type="advertising",
            service_code=package_code,
            amount_mad=amount_mad,
            currency=currency,
            success_url=success_url,
            cancel_url=cancel_url,
            description=f"Dribex advertising — {package_code}",
            extra_metadata={k: str(v) for k, v in metadata.items() if v is not None},
        )

    async def _create_checkout(
        self,
        *,
        payment_id: UUID,
        user_id: UUID,
        service_type: str,
        service_code: str,
        amount_mad: float,
        currency: str,
        success_url: str,
        cancel_url: str,
        description: str,
        extra_metadata: dict[str, str] | None = None,
    ) -> CheckoutSession:
        metadata = {
            "dribex_payment_id": str(payment_id),
            "dribex_user_id": str(user_id),
            "dribex_service_type": service_type,
            "dribex_service_code": service_code,
        }
        if extra_metadata:
            metadata.update(extra_metadata)

        try:
            result = await self._client.initiate_hosted_payment(
                order_id=str(payment_id),
                amount_mad=Decimal(str(amount_mad)),
                currency=currency,
                description=description,
                success_url=success_url,
                cancel_url=cancel_url,
                customer_email=None,
                metadata=metadata,
            )
        except NapsIntegrationNotConfiguredError:
            raise
        except Exception as exc:
            raise ValueError(f"NAPS payment initiation failed: {exc}") from exc

        self.log_event(
            "checkout_created",
            payment_id=payment_id,
            provider_payment_id=result.provider_payment_id,
        )
        return CheckoutSession(
            payment_id=payment_id,
            checkout_url=result.redirect_url,
            provider=self.name,
            provider_reference=result.provider_payment_id,
            status="pending",
        )

    def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook:
        self._client.verify_webhook_signature(payload=payload, signature_header=signature_header)
        body = self._client.parse_webhook_payload(payload)

        event_id = str(body.get(settings.naps_webhook_event_id_field, "") or body.get("event_id", ""))
        if not event_id:
            raise ValueError("NAPS webhook missing event ID")

        status = str(body.get(settings.naps_webhook_status_field, "") or body.get("status", ""))
        provider_reference = str(
            body.get(settings.naps_webhook_payment_id_field, "")
            or body.get("payment_id", "")
            or body.get("order_id", "")
        )
        metadata = body.get("metadata") if isinstance(body.get("metadata"), dict) else body

        amount = body.get(settings.naps_webhook_amount_field) or body.get("amount")
        currency = body.get(settings.naps_webhook_currency_field) or body.get("currency") or settings.payment_currency

        dribex_payment_id = ""
        if isinstance(metadata, dict):
            dribex_payment_id = str(metadata.get("dribex_payment_id", "") or metadata.get("order_id", ""))

        return VerifiedWebhook(
            event_id=event_id,
            event_type=status.lower(),
            provider_reference=provider_reference,
            amount_mad=float(amount) if amount is not None else None,
            currency=str(currency).lower() if currency else settings.payment_currency,
            metadata={
                **(metadata if isinstance(metadata, dict) else {}),
                "dribex_payment_id": dribex_payment_id,
            },
        )
