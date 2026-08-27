"""Email provider abstraction — Brevo API (production) and log fallback (development)."""

from __future__ import annotations

import logging
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger("margem.email.provider")

_BREVO_SEND_URL = "https://api.brevo.com/v3/smtp/email"


@dataclass(frozen=True)
class ProviderSendResult:
    delivered: bool
    mode: str
    provider: str
    attempts: int = 1
    error: str | None = None


class EmailProvider(ABC):
    name: str

    @abstractmethod
    def send(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        reply_to: str | None = None,
    ) -> ProviderSendResult: ...


class LogEmailProvider(EmailProvider):
    name = "log"

    def send(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        reply_to: str | None = None,
    ) -> ProviderSendResult:
        from app.services.email_redaction import mask_email, safe_preview

        _ = reply_to, html_body
        logger.info(
            "email_dev_fallback provider=log to=%s subject=%s body=%s",
            mask_email(to),
            subject,
            safe_preview(text_body),
        )
        return ProviderSendResult(delivered=False, mode="log", provider=self.name)


class BrevoEmailProvider(EmailProvider):
    """Send transactional email through the Brevo REST API."""

    name = "brevo"

    def send(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        reply_to: str | None = None,
    ) -> ProviderSendResult:
        from app.services.email_redaction import mask_email

        api_key = settings.brevo_api_key.strip()
        if not api_key:
            logger.error("email_send_failed provider=brevo error=missing_api_key to=%s", mask_email(to))
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error="missing_api_key",
            )

        sender_email = settings.brevo_sender_email.strip()
        if not sender_email or "@" not in sender_email:
            logger.error(
                "email_send_failed provider=brevo error=missing_sender_email to=%s",
                mask_email(to),
            )
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error="missing_sender_email",
            )

        sender_name = settings.brevo_sender_name.strip() or "Dribex"
        payload: dict[str, Any] = {
            "sender": {"name": sender_name, "email": sender_email},
            "to": [{"email": to}],
            "subject": subject,
            "textContent": text_body,
        }
        if html_body:
            payload["htmlContent"] = html_body
        if reply_to:
            payload["replyTo"] = {"email": reply_to}

        try:
            with httpx.Client(timeout=settings.email_send_timeout_seconds) as client:
                response = client.post(
                    _BREVO_SEND_URL,
                    headers={
                        "api-key": api_key,
                        "Content-Type": "application/json",
                        "accept": "application/json",
                    },
                    json=payload,
                )
                if response.status_code >= 400:
                    detail = _safe_brevo_error_detail(response)
                    logger.error(
                        "email_send_failed provider=brevo to=%s subject=%s status=%s detail=%s",
                        mask_email(to),
                        subject,
                        response.status_code,
                        detail,
                    )
                    return ProviderSendResult(
                        delivered=False,
                        mode="provider_error",
                        provider=self.name,
                        error=f"http_{response.status_code}",
                    )
        except httpx.TimeoutException:
            logger.error(
                "email_send_failed provider=brevo to=%s subject=%s error=timeout",
                mask_email(to),
                subject,
            )
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error="timeout",
            )
        except httpx.HTTPError as exc:
            logger.exception(
                "email_send_failed provider=brevo to=%s subject=%s error=%s",
                mask_email(to),
                subject,
                type(exc).__name__,
            )
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error=type(exc).__name__,
            )

        return ProviderSendResult(delivered=True, mode="api", provider=self.name)


def _safe_brevo_error_detail(response: httpx.Response) -> str:
    """Extract a short Brevo error message without leaking secrets from the response body."""
    try:
        body = response.json()
        if isinstance(body, dict):
            message = str(body.get("message") or body.get("code") or "").strip()
            if message:
                return message[:200]
    except ValueError:
        pass
    return f"status_{response.status_code}"


_provider_cache: EmailProvider | None = None


def get_email_provider() -> EmailProvider:
    global _provider_cache
    if _provider_cache is not None:
        return _provider_cache
    provider = settings.effective_email_provider
    if provider == "log":
        _provider_cache = LogEmailProvider()
    else:
        _provider_cache = BrevoEmailProvider()
    return _provider_cache


def reset_email_provider_cache() -> None:
    global _provider_cache
    _provider_cache = None


def send_with_retries(provider: EmailProvider, **kwargs: Any) -> ProviderSendResult:
    attempts = max(1, settings.email_max_retries + 1)
    last_result = ProviderSendResult(delivered=False, mode="unknown", provider=provider.name)
    for attempt in range(1, attempts + 1):
        last_result = provider.send(**kwargs)
        last_result = ProviderSendResult(
            delivered=last_result.delivered,
            mode=last_result.mode,
            provider=last_result.provider,
            attempts=attempt,
            error=last_result.error,
        )
        if last_result.delivered or last_result.mode == "log":
            return last_result
        if attempt < attempts:
            time.sleep(settings.email_retry_delay_seconds)
    return last_result
