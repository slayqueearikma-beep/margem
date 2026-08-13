"""Resolve the client IP behind reverse proxies when configured."""

from __future__ import annotations

from starlette.requests import Request

from app.config import settings


def get_client_ip(request: Request) -> str:
    """Return the client IP, honoring X-Forwarded-For only when TRUSTED_PROXY_HOPS > 0."""
    if request.client is None:
        return "unknown"

    direct = request.client.host
    hops = max(0, int(getattr(settings, "trusted_proxy_hops", 0) or 0))
    if hops <= 0:
        return direct

    forwarded = request.headers.get("x-forwarded-for")
    if not forwarded:
        return direct

    parts = [part.strip() for part in forwarded.split(",") if part.strip()]
    if not parts:
        return direct

    # Rightmost untrusted hop is len(parts) - hops - 1 from the end.
    index = max(0, len(parts) - hops - 1)
    return parts[index]
