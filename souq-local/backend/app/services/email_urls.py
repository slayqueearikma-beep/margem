"""Trusted application URL builder for transactional email links."""

from __future__ import annotations

from urllib.parse import quote, urlencode, urlparse

from app.config import settings

_STRICT_ENVS = frozenset({"production", "prod", "staging", "preprod", "preview"})


def _trusted_app_base() -> str:
    base = settings.public_app_url.strip().rstrip("/")
    if not base:
        raise ValueError("PUBLIC_APP_URL is not configured")
    parsed = urlparse(base)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("PUBLIC_APP_URL must use http or https")
    if not parsed.netloc:
        raise ValueError("PUBLIC_APP_URL must include a host")
    if settings.app_env in _STRICT_ENVS and parsed.scheme != "https":
        raise ValueError("PUBLIC_APP_URL must use HTTPS for email links in this environment")
    return base


def build_app_url(path: str, *, query: dict[str, str] | None = None) -> str:
    """Build an absolute HTTPS app URL using configured PUBLIC_APP_URL only."""
    normalized_path = path if path.startswith("/") else f"/{path}"
    base = _trusted_app_base()
    url = f"{base}{normalized_path}"
    if query:
        encoded = urlencode({key: value for key, value in query.items() if value})
        if encoded:
            url = f"{url}?{encoded}"
    return url


def build_deep_link(path: str, *, query: dict[str, str] | None = None) -> str:
    normalized_path = path if path.startswith("/") else f"/{path}"
    url = f"margem://app{normalized_path}"
    if query:
        encoded = urlencode({key: value for key, value in query.items() if value})
        if encoded:
            url = f"{url}?{encoded}"
    return url


def build_reset_password_urls(token: str) -> tuple[str, str]:
    query = {"token": token}
    return build_app_url("/reset-password", query=query), build_deep_link("/reset-password", query=query)


def build_verify_email_urls(token: str) -> tuple[str, str]:
    query = {"token": token}
    return build_app_url("/verify-email", query=query), build_deep_link("/verify-email", query=query)
