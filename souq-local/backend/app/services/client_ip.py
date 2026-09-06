"""Trusted client IP resolution for rate limiting and audit logs."""

from __future__ import annotations

from ipaddress import ip_address, ip_network

from fastapi import Request

from app.config import settings


def ip_permitted(ip: str, allowlist: list[str]) -> bool:
    """Return True when [ip] is loopback or contained in [allowlist] CIDRs/hosts."""
    try:
        addr = ip_address(ip)
    except ValueError:
        return False
    if addr.is_loopback:
        return True
    for entry in allowlist:
        entry = entry.strip()
        if not entry:
            continue
        try:
            if "/" in entry:
                if addr in ip_network(entry, strict=False):
                    return True
            elif addr == ip_address(entry):
                return True
        except ValueError:
            continue
    return False


def is_internal_network_access(request: Request, *, allowlist: list[str] | None = None) -> bool:
    """True when the request originates from loopback or an configured allowlist."""
    resolved = allowlist if allowlist is not None else settings.admin_ip_allowlist
    if not resolved:
        return ip_permitted(get_client_ip(request), [])
    return ip_permitted(get_client_ip(request), resolved)


def get_client_ip(request: Request) -> str:
    """Resolve the client IP behind zero or more trusted reverse proxies.

    When ``trusted_proxy_hops`` is set, the leftmost ``X-Forwarded-For`` entry
    is used (Azure ACA / Front Door append the real client IP). Direct client
    connections ignore spoofed forwarding headers.
    """
    if settings.trusted_proxy_hops > 0:
        forwarded = request.headers.get("x-forwarded-for") or request.headers.get(
            "X-Forwarded-For"
        )
        if forwarded:
            parts = [part.strip() for part in forwarded.split(",") if part.strip()]
            if parts:
                return parts[0]

    if request.client and request.client.host:
        return request.client.host
    return "127.0.0.1"
