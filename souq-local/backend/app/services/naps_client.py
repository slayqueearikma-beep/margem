"""NAPS ePay integration boundary for Moroccan online payments.

Official NAPS ePay merchant API documentation is provided by NAPS SA after merchant
affiliation (https://naps.ma/paiements-en-ligne/). This module does NOT invent NAPS
protocol details — it reads endpoint URLs, field mappings, and credentials from
environment variables supplied with the merchant integration guide.

Missing official documentation must be configured before production use.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger("margem.naps")


class NapsIntegrationNotConfiguredError(ValueError):
    """Raised when required NAPS merchant integration settings are absent."""


class NapsIntegrationError(ValueError):
    """Raised when NAPS returns an unexpected or invalid response."""


@dataclass(frozen=True)
class NapsPaymentInitResult:
    provider_payment_id: str
    redirect_url: str


@dataclass(frozen=True)
class NapsPaymentStatusResult:
    provider_payment_id: str
    status: str
    amount: Decimal | None
    currency: str | None


def _require_config() -> None:
    missing = settings.naps_missing_config_fields()
    if missing:
        raise NapsIntegrationNotConfiguredError(
            "NAPS ePay is not fully configured. Missing: "
            + ", ".join(missing)
            + ". Obtain values from the official NAPS merchant integration guide."
        )


def _sign_payload(payload: dict[str, Any]) -> str:
    secret = settings.naps_secret_key.strip()
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hmac.new(secret.encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256).hexdigest()


def _extract_path(data: dict[str, Any], path: str) -> Any:
    current: Any = data
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


class NapsClient:
    """HTTP client for NAPS ePay hosted payment flows."""

    async def initiate_hosted_payment(
        self,
        *,
        order_id: str,
        amount_mad: Decimal,
        currency: str,
        description: str,
        success_url: str,
        cancel_url: str,
        customer_email: str | None,
        metadata: dict[str, str],
    ) -> NapsPaymentInitResult:
        _require_config()
        payload: dict[str, Any] = {
            "merchant_id": settings.naps_merchant_id.strip(),
            "order_id": order_id,
            "amount": float(amount_mad),
            "currency": currency.upper(),
            "description": description,
            "success_url": success_url,
            "cancel_url": cancel_url,
        }
        if customer_email:
            payload["customer_email"] = customer_email
        payload.update(settings.naps_extra_request_fields)
        payload["metadata"] = metadata
        if settings.naps_request_signing_enabled:
            payload["signature"] = _sign_payload({k: v for k, v in payload.items() if k != "signature"})

        headers = {"Content-Type": "application/json"}
        if settings.naps_api_key.strip():
            headers[settings.naps_api_key_header] = settings.naps_api_key.strip()

        url = settings.naps_epay_payment_init_url.strip()
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, json=payload, headers=headers)
        if response.status_code >= 400:
            logger.warning("naps_payment_init_failed status=%s body=%s", response.status_code, response.text[:500])
            raise NapsIntegrationError("NAPS payment initiation failed")

        body = response.json()
        payment_id = _extract_path(body, settings.naps_response_payment_id_path)
        redirect_url = _extract_path(body, settings.naps_response_redirect_url_path)
        if not payment_id or not redirect_url:
            raise NapsIntegrationError(
                "NAPS response missing payment ID or redirect URL. "
                "Verify NAPS_RESPONSE_PAYMENT_ID_PATH and NAPS_RESPONSE_REDIRECT_URL_PATH "
                "against the official merchant integration guide."
            )
        return NapsPaymentInitResult(provider_payment_id=str(payment_id), redirect_url=str(redirect_url))

    async def query_payment_status(self, *, provider_payment_id: str) -> NapsPaymentStatusResult:
        _require_config()
        if not settings.naps_epay_payment_status_url.strip():
            raise NapsIntegrationNotConfiguredError(
                "NAPS_EPAY_PAYMENT_STATUS_URL is required for payment status queries."
            )

        payload = {
            "merchant_id": settings.naps_merchant_id.strip(),
            "payment_id": provider_payment_id,
        }
        if settings.naps_request_signing_enabled:
            payload["signature"] = _sign_payload(payload)

        headers = {"Content-Type": "application/json"}
        if settings.naps_api_key.strip():
            headers[settings.naps_api_key_header] = settings.naps_api_key.strip()

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(settings.naps_epay_payment_status_url.strip(), json=payload, headers=headers)
        if response.status_code >= 400:
            raise NapsIntegrationError("NAPS payment status query failed")

        body = response.json()
        status = _extract_path(body, settings.naps_response_status_path)
        amount_raw = _extract_path(body, settings.naps_response_amount_path)
        currency = _extract_path(body, settings.naps_response_currency_path)
        amount = Decimal(str(amount_raw)) if amount_raw is not None else None
        return NapsPaymentStatusResult(
            provider_payment_id=provider_payment_id,
            status=str(status or "unknown"),
            amount=amount,
            currency=str(currency).lower() if currency else None,
        )

    def verify_webhook_signature(self, *, payload: bytes, signature_header: str | None) -> None:
        if not settings.naps_webhook_secret.strip():
            raise NapsIntegrationNotConfiguredError("NAPS_WEBHOOK_SECRET is required for webhook verification.")
        if not signature_header:
            raise ValueError("Missing NAPS webhook signature header")
        expected = hmac.new(
            settings.naps_webhook_secret.strip().encode("utf-8"),
            payload,
            hashlib.sha256,
        ).hexdigest()
        if not hmac.compare_digest(expected, signature_header.strip()):
            raise ValueError("Invalid NAPS webhook signature")

    def parse_webhook_payload(self, payload: bytes) -> dict[str, Any]:
        try:
            body = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise ValueError("Invalid NAPS webhook JSON") from exc
        if not isinstance(body, dict):
            raise ValueError("Invalid NAPS webhook payload")
        return body
