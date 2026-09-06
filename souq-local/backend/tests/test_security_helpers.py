"""Security helper tests."""

from unittest.mock import MagicMock

import pytest

from app.services.client_ip import get_client_ip
from app.services.text_sanitizer import sanitize_free_text
from app.services.upload_security import validate_presign_upload_url


def test_get_client_ip_uses_forwarded_for_when_trusted():
    request = MagicMock()
    request.headers = {"x-forwarded-for": "203.0.113.10, 10.0.0.1"}
    request.client = MagicMock(host="127.0.0.1")

    from app.config import settings

    original = settings.trusted_proxy_hops
    settings.trusted_proxy_hops = 1
    try:
        assert get_client_ip(request) == "203.0.113.10"
    finally:
        settings.trusted_proxy_hops = original


def test_get_client_ip_ignores_forwarded_without_trusted_proxy():
    request = MagicMock()
    request.headers = {"x-forwarded-for": "203.0.113.10"}
    request.client = MagicMock(host="198.51.100.4")

    from app.config import settings

    original = settings.trusted_proxy_hops
    settings.trusted_proxy_hops = 0
    try:
        assert get_client_ip(request) == "198.51.100.4"
    finally:
        settings.trusted_proxy_hops = original


def test_validate_presign_upload_url_allows_azure_blob():
    validate_presign_upload_url(
        "https://account.blob.core.windows.net/media/user/file.jpg?sas=1",
        public_api_url="https://api.example.com",
    )


def test_validate_presign_upload_url_rejects_unknown_host():
    with pytest.raises(ValueError, match="not allowed"):
        validate_presign_upload_url(
            "https://evil.example/upload",
            public_api_url="https://api.example.com",
        )


def test_sanitize_free_text_strips_control_chars():
    assert sanitize_free_text("hello\x00world", max_length=20) == "helloworld"
