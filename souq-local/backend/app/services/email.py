"""Centralized transactional email service."""

from __future__ import annotations

import asyncio
import logging
from enum import Enum
from typing import Any

from app.config import settings
from app.services.email_provider import ProviderSendResult, get_email_provider, send_with_retries
from app.services.email_redaction import mask_email, safe_preview
from app.services.email_templates import (
    render_email_verification,
    render_notification,
    render_password_reset,
    render_security_alert,
    render_signup_otp,
    render_welcome,
)
from app.services.email_urls import build_reset_password_urls, build_verify_email_urls

logger = logging.getLogger("margem.email")

# Backward-compatible aliases used by provider modules.
_mask_email = mask_email
_safe_preview = safe_preview


class EmailType(str, Enum):
    PASSWORD_RESET = "password_reset"
    EMAIL_VERIFICATION = "email_verification"
    SIGNUP_OTP = "signup_otp"
    SECURITY_ALERT = "security_alert"
    WELCOME = "welcome"
    NOTIFICATION = "notification"


class SecurityAlertKind(str, Enum):
    PASSWORD_CHANGED = "password_changed"
    EMAIL_CHANGED = "email_changed"
    MFA_ENABLED = "mfa_enabled"
    MFA_DISABLED = "mfa_disabled"
    SUSPICIOUS_LOGIN = "suspicious_login"
    ACCOUNT_LOCKED = "account_locked"


class EmailService:
    def _deliver(
        self,
        *,
        email_type: EmailType,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        provider = get_email_provider()
        result = send_with_retries(
            provider,
            to=to,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            reply_to=settings.effective_email_reply_to or None,
        )
        self._log_delivery(email_type=email_type, to=to, user_id=user_id, result=result)
        return {
            "delivered": result.delivered,
            "mode": result.mode,
            "provider": result.provider,
            "attempts": result.attempts,
            "error": result.error,
        }

    def _log_delivery(
        self,
        *,
        email_type: EmailType,
        to: str,
        user_id: str | None,
        result: ProviderSendResult,
    ) -> None:
        status = "delivered" if result.delivered else "failed"
        if result.mode == "log":
            status = "logged"
        logger.info(
            "email_delivery email_type=%s provider=%s status=%s attempts=%s user_id=%s to=%s error=%s",
            email_type.value,
            result.provider,
            status,
            result.attempts,
            user_id or "-",
            mask_email(to),
            result.error or "-",
        )

    def send(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        email_type: EmailType = EmailType.NOTIFICATION,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        """Low-level send API retained for compatibility."""
        return self._deliver(
            email_type=email_type,
            to=to,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            user_id=user_id,
        )

    def send_password_reset(
        self,
        *,
        to: str,
        token: str,
        expires_hours: int | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        web_url, deep_url = build_reset_password_urls(token)
        rendered = render_password_reset(
            web_url=web_url,
            deep_url=deep_url,
            expires_hours=expires_hours or settings.password_reset_expire_hours,
        )
        return self._deliver(
            email_type=EmailType.PASSWORD_RESET,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_email_verification(
        self,
        *,
        to: str,
        token: str,
        expires_minutes: int = 15,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        web_url, deep_url = build_verify_email_urls(token)
        rendered = render_email_verification(
            web_url=web_url,
            deep_url=deep_url,
            code=token,
            expires_minutes=expires_minutes,
        )
        return self._deliver(
            email_type=EmailType.EMAIL_VERIFICATION,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_signup_otp(
        self,
        *,
        to: str,
        code: str,
        expires_minutes: int = 10,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        rendered = render_signup_otp(code=code, expires_minutes=expires_minutes)
        return self._deliver(
            email_type=EmailType.SIGNUP_OTP,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_welcome_email(
        self,
        *,
        to: str,
        display_name: str | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        rendered = render_welcome(display_name=display_name)
        return self._deliver(
            email_type=EmailType.WELCOME,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_security_alert(
        self,
        *,
        to: str,
        alert_type: SecurityAlertKind | str,
        message: str,
        detail_lines: list[str] | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        rendered = render_security_alert(
            alert_type=str(alert_type),
            message=message,
            detail_lines=detail_lines,
        )
        return self._deliver(
            email_type=EmailType.SECURITY_ALERT,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_notification(
        self,
        *,
        to: str,
        subject: str,
        message: str,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        rendered = render_notification(subject=subject, message=message)
        return self._deliver(
            email_type=EmailType.NOTIFICATION,
            to=to,
            subject=rendered.subject,
            text_body=rendered.text_body,
            html_body=rendered.html_body,
            user_id=user_id,
        )

    def send_otp_email(
        self,
        *,
        to: str,
        code: str,
        expires_minutes: int = 10,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        return self.send_signup_otp(
            to=to,
            code=code,
            expires_minutes=expires_minutes,
            user_id=user_id,
        )

    def send_password_reset_email(
        self,
        *,
        to: str,
        token: str,
        expires_hours: int | None = None,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        return self.send_password_reset(
            to=to,
            token=token,
            expires_hours=expires_hours,
            user_id=user_id,
        )

    def send_verification_email(
        self,
        *,
        to: str,
        token: str,
        expires_minutes: int = 15,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        return self.send_email_verification(
            to=to,
            token=token,
            expires_minutes=expires_minutes,
            user_id=user_id,
        )

    def send_transactional_email(
        self,
        *,
        to: str,
        subject: str,
        text_body: str,
        html_body: str | None = None,
        email_type: EmailType = EmailType.NOTIFICATION,
        user_id: str | None = None,
    ) -> dict[str, Any]:
        return self.send(
            to=to,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            email_type=email_type,
            user_id=user_id,
        )

    async def send_password_reset_async(self, **kwargs: Any) -> dict[str, Any]:
        return await asyncio.to_thread(self.send_password_reset, **kwargs)

    async def send_email_verification_async(self, **kwargs: Any) -> dict[str, Any]:
        return await asyncio.to_thread(self.send_email_verification, **kwargs)

    async def send_signup_otp_async(self, **kwargs: Any) -> dict[str, Any]:
        return await asyncio.to_thread(self.send_signup_otp, **kwargs)

    async def send_welcome_email_async(self, **kwargs: Any) -> dict[str, Any]:
        return await asyncio.to_thread(self.send_welcome_email, **kwargs)

    async def send_security_alert_async(self, **kwargs: Any) -> dict[str, Any]:
        return await asyncio.to_thread(self.send_security_alert, **kwargs)

    def _queue(self, async_fn, sync_fn, **kwargs: Any) -> None:
        async def _task() -> None:
            await async_fn(**kwargs)

        try:
            asyncio.get_running_loop().create_task(_task())
        except RuntimeError:
            sync_fn(**kwargs)

    def queue_password_reset(self, **kwargs: Any) -> None:
        self._queue(self.send_password_reset_async, self.send_password_reset, **kwargs)

    def queue_email_verification(self, **kwargs: Any) -> None:
        self._queue(self.send_email_verification_async, self.send_email_verification, **kwargs)

    def queue_signup_otp(self, **kwargs: Any) -> None:
        self._queue(self.send_signup_otp_async, self.send_signup_otp, **kwargs)

    def queue_welcome_email(self, **kwargs: Any) -> None:
        self._queue(self.send_welcome_email_async, self.send_welcome_email, **kwargs)

    def queue_security_alert(self, **kwargs: Any) -> None:
        self._queue(self.send_security_alert_async, self.send_security_alert, **kwargs)


email_service = EmailService()
