"""Payment provider abstraction — Dribex service revenue only (not marketplace checkout)."""

from __future__ import annotations

import hashlib
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any
from uuid import UUID

logger = logging.getLogger("margem.billing")


@dataclass(frozen=True)
class CheckoutSession:
    payment_id: UUID
    checkout_url: str | None
    provider: str
    provider_reference: str
    status: str


@dataclass(frozen=True)
class VerifiedWebhook:
    event_id: str
    event_type: str
    provider_reference: str
    amount_mad: float | None
    currency: str | None
    metadata: dict[str, Any]


class PaymentProvider(ABC):
    name: str

    @abstractmethod
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
    ) -> CheckoutSession: ...

    @abstractmethod
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
        metadata: dict[str, Any],
    ) -> CheckoutSession: ...

    @abstractmethod
    def verify_webhook(self, *, payload: bytes, signature_header: str | None) -> VerifiedWebhook: ...

    def log_event(self, event: str, **fields: object) -> None:
        logger.info(
            "billing_event event=%s provider=%s %s",
            event,
            self.name,
            " ".join(f"{k}={v}" for k, v in fields.items()),
        )


_provider_cache: PaymentProvider | None = None


def get_payment_provider() -> PaymentProvider:
    global _provider_cache
    if _provider_cache is not None:
        return _provider_cache
    from app.config import settings

    if settings.payment_provider == "naps":
        from app.services.naps_payment_provider import NapsPaymentProvider

        _provider_cache = NapsPaymentProvider()
    elif settings.payment_provider == "none":
        from app.services.manual_payment_provider import DisabledPaymentProvider

        _provider_cache = DisabledPaymentProvider()
    else:
        from app.services.manual_payment_provider import ManualPaymentProvider

        _provider_cache = ManualPaymentProvider()
    return _provider_cache


def reset_payment_provider_cache() -> None:
    global _provider_cache
    _provider_cache = None


def hash_webhook_payload(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()
