"""Centralized email service tests."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import httpx
import pytest
from pydantic import ValidationError

from app.config import Settings, settings
from app.services.email import EmailService, SecurityAlertKind, email_service
from app.services.email_provider import (
    BrevoEmailProvider,
    LogEmailProvider,
    ProviderSendResult,
    reset_email_provider_cache,
)
from app.services.email_redaction import mask_email, safe_preview
from app.services.email_templates import render_password_reset
from app.services.email_urls import build_reset_password_urls

from tests.settings_helpers import _PROD_BREVO, _PROD_NAPS


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_email_provider_cache()
    yield
    reset_email_provider_cache()


def test_safe_preview_redacts_tokens_and_otps():
    body = "Reset link https://dribex.ma/reset-password?token=super-secret-token-1234567890 and code 123456"
    preview = safe_preview(body)
    assert "super-secret-token" not in preview
    assert "123456" not in preview
    assert "[REDACTED]" in preview


def test_mask_email_redacts_local_part():
    assert mask_email("alice@example.com") == "a***@example.com"


def test_build_reset_password_urls_use_public_app_url(monkeypatch):
    monkeypatch.setenv("PUBLIC_APP_URL", "https://dribex.ma")
    web, deep = build_reset_password_urls("abc123token")
    assert web == "https://dribex.ma/reset-password?token=abc123token"
    assert deep == "margem://app/reset-password?token=abc123token"


def test_password_reset_template_includes_action_and_security_note():
    rendered = render_password_reset(
        web_url="https://dribex.ma/reset-password?token=abc",
        deep_url="margem://app/reset-password?token=abc",
        expires_hours=2,
    )
    assert rendered.subject == "Reset your Dribex password"
    assert "Reset password" in rendered.html_body
    assert "https://dribex.ma/reset-password?token=abc" in rendered.text_body
    assert "If you did not request a password reset" in rendered.text_body


def test_log_provider_never_raises():
    provider = LogEmailProvider()
    result = provider.send(
        to="user@example.com",
        subject="Test",
        text_body="Your code is 123456 and token=abcdef1234567890",
    )
    assert result.delivered is False
    assert result.mode == "log"


def test_email_service_send_password_reset_uses_provider():
    service = EmailService()
    provider = MagicMock()
    provider.name = "brevo"
    provider.send.return_value = ProviderSendResult(delivered=True, mode="api", provider="brevo")
    with patch("app.services.email.get_email_provider", return_value=provider):
        result = service.send_password_reset_email(to="user@example.com", token="x" * 32, user_id="user-1")
    assert result["delivered"] is True
    provider.send.assert_called_once()
    kwargs = provider.send.call_args.kwargs
    assert kwargs["to"] == "user@example.com"
    assert kwargs["html_body"]


def test_email_service_retries_on_provider_failure():
    service = EmailService()
    provider = MagicMock()
    provider.name = "brevo"
    provider.send.side_effect = [
        ProviderSendResult(delivered=False, mode="provider_error", provider="brevo", error="timeout"),
        ProviderSendResult(delivered=True, mode="api", provider="brevo"),
    ]
    with patch("app.services.email.get_email_provider", return_value=provider):
        with patch("app.services.email_provider.time.sleep"):
            result = service.send_security_alert(
                to="user@example.com",
                alert_type=SecurityAlertKind.MFA_ENABLED,
                message="MFA enabled.",
                user_id="user-1",
            )
    assert result["delivered"] is True
    assert provider.send.call_count == 2


def test_production_requires_brevo_configuration():
    with pytest.raises(ValidationError, match="BREVO_API_KEY"):
        Settings(
            _env_file=None,
            app_env="production",
            debug=False,
            jwt_secret_key="x" * 32,
            upload_token_secret="y" * 32,
            mfa_encryption_key="z" * 32,
            brevo_api_key="",
            allow_insecure_email_fallback=False,
            cors_origins=["https://dribex.ma"],
            allowed_hosts=["dribex.ma"],
            public_api_url="https://api.dribex.ma",
            public_app_url="https://dribex.ma",
            admin_ip_allowlist=["10.0.0.0/8"],
            **_PROD_NAPS,
        )


def test_brevo_provider_requires_api_key():
    result = BrevoEmailProvider().send(
        to="user@example.com",
        subject="Test",
        text_body="Hello",
    )
    assert result.delivered is False
    assert result.error == "missing_api_key"


def test_brevo_provider_requires_sender_email():
    with patch.object(settings, "brevo_api_key", "test-api-key-not-real"):
        with patch.object(settings, "brevo_sender_email", ""):
            result = BrevoEmailProvider().send(
                to="user@example.com",
                subject="Test",
                text_body="Hello",
            )
    assert result.delivered is False
    assert result.error == "missing_sender_email"


def test_brevo_provider_success():
    with patch.object(settings, "brevo_api_key", "test-api-key-not-real"):
        with patch.object(settings, "brevo_sender_email", "noreply@dribex.ma"):
            with patch.object(settings, "brevo_sender_name", "Dribex"):
                class FakeResponse:
                    status_code = 201

                    @staticmethod
                    def json():
                        return {"messageId": "<test-id>"}

                with patch("httpx.Client.post", return_value=FakeResponse()):
                    result = BrevoEmailProvider().send(
                        to="user@example.com",
                        subject="Verify your email",
                        text_body="Code 123456",
                        html_body="<p>Code 123456</p>",
                    )
    assert result.delivered is True
    assert result.provider == "brevo"
    assert result.mode == "api"


def test_brevo_provider_http_error():
    with patch.object(settings, "brevo_api_key", "test-api-key-not-real"):
        with patch.object(settings, "brevo_sender_email", "noreply@dribex.ma"):
            class FakeResponse:
                status_code = 401

                @staticmethod
                def json():
                    return {"message": "Key not found"}

            with patch("httpx.Client.post", return_value=FakeResponse()):
                result = BrevoEmailProvider().send(
                    to="user@example.com",
                    subject="Test",
                    text_body="Hello",
                )
    assert result.delivered is False
    assert result.error == "http_401"


def test_brevo_provider_timeout():
    with patch.object(settings, "brevo_api_key", "test-api-key-not-real"):
        with patch.object(settings, "brevo_sender_email", "noreply@dribex.ma"):
            with patch("httpx.Client.post", side_effect=httpx.TimeoutException("timed out")):
                result = BrevoEmailProvider().send(
                    to="user@example.com",
                    subject="Test",
                    text_body="Hello",
                )
    assert result.delivered is False
    assert result.error == "timeout"


def test_security_alert_delivery_modes():
    result = email_service.send_security_alert(
        to="user@example.com",
        alert_type=SecurityAlertKind.PASSWORD_CHANGED,
        message="Your password was successfully changed.",
        user_id="abc",
    )
    assert result["mode"] in {"log", "api", "provider_error"}
    assert result["provider"] in {"log", "brevo"}
