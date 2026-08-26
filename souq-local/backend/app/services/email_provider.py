"""Email provider abstraction — log fallback, SMTP, and HTTP API providers."""

from __future__ import annotations

import logging
import smtplib
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from email.message import EmailMessage
from typing import Any

import httpx

from app.config import settings

logger = logging.getLogger("margem.email.provider")


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


class SmtpEmailProvider(EmailProvider):
    name = "smtp"

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

        message = EmailMessage()
        message["From"] = settings.effective_from_header
        message["To"] = to
        message["Subject"] = subject
        if reply_to:
            message["Reply-To"] = reply_to
        message.set_content(text_body)
        if html_body:
            message.add_alternative(html_body, subtype="html")

        try:
            with smtplib.SMTP(
                settings.effective_email_host,
                settings.effective_email_port,
                timeout=settings.email_send_timeout_seconds,
            ) as smtp:
                if settings.effective_email_use_tls:
                    smtp.starttls()
                username = settings.effective_email_username
                if username:
                    smtp.login(username, settings.effective_email_password)
                smtp.send_message(message)
        except (OSError, smtplib.SMTPException) as exc:
            logger.exception(
                "email_send_failed provider=smtp to=%s subject=%s error=%s",
                mask_email(to),
                subject,
                exc,
            )
            return ProviderSendResult(
                delivered=False,
                mode="smtp_error",
                provider=self.name,
                error=type(exc).__name__,
            )
        return ProviderSendResult(delivered=True, mode="smtp", provider=self.name)


class ResendEmailProvider(EmailProvider):
    name = "resend"

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

        api_key = settings.effective_email_password
        if not api_key:
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error="missing_api_key",
            )

        payload: dict[str, Any] = {
            "from": settings.effective_from_header,
            "to": [to],
            "subject": subject,
            "text": text_body,
        }
        if html_body:
            payload["html"] = html_body
        if reply_to:
            payload["reply_to"] = reply_to

        try:
            with httpx.Client(timeout=settings.email_send_timeout_seconds) as client:
                response = client.post(
                    "https://api.resend.com/emails",
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                )
                if response.status_code >= 400:
                    logger.error(
                        "email_send_failed provider=resend to=%s subject=%s status=%s",
                        mask_email(to),
                        subject,
                        response.status_code,
                    )
                    return ProviderSendResult(
                        delivered=False,
                        mode="provider_error",
                        provider=self.name,
                        error=f"http_{response.status_code}",
                    )
        except httpx.HTTPError as exc:
            logger.exception(
                "email_send_failed provider=resend to=%s subject=%s error=%s",
                mask_email(to),
                subject,
                exc,
            )
            return ProviderSendResult(
                delivered=False,
                mode="provider_error",
                provider=self.name,
                error=type(exc).__name__,
            )
        return ProviderSendResult(delivered=True, mode="api", provider=self.name)


_provider_cache: EmailProvider | None = None


def get_email_provider() -> EmailProvider:
    global _provider_cache
    if _provider_cache is not None:
        return _provider_cache
    provider = settings.effective_email_provider
    if provider == "log":
        _provider_cache = LogEmailProvider()
    elif provider == "resend":
        _provider_cache = ResendEmailProvider()
    else:
        _provider_cache = SmtpEmailProvider()
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
