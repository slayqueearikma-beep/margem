"""URL safety checks for user-supplied links (QR targets, seller websites, social URLs)."""

from __future__ import annotations

from ipaddress import ip_address
from urllib.parse import urlparse


def _hostname_is_private_or_local(host: str) -> bool:
    host = (host or "").strip().lower().rstrip(".")
    if not host:
        return True
    if host in {"localhost", "127.0.0.1", "0.0.0.0", "::1"}:
        return True
    if host.endswith(".local") or host.endswith(".internal"):
        return True
    try:
        addr = ip_address(host)
    except ValueError:
        return False
    return bool(addr.is_private or addr.is_loopback or addr.is_link_local or addr.is_reserved)


def reject_private_or_internal_url(url: str, *, field_name: str = "url") -> str:
    """Reject URLs that expose private infrastructure (QR / website safety)."""
    cleaned = url.strip()
    if not cleaned:
        return ""
    parsed = urlparse(cleaned)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"{field_name} must be an absolute http(s) URL")
    host = parsed.hostname or ""
    if _hostname_is_private_or_local(host):
        raise ValueError(f"{field_name} must not point to private or internal addresses")
    return cleaned
