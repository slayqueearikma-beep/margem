"""Trusted client IP resolution for rate limiting and audit logs."""

from __future__ import annotations

from fastapi import Request

from app.config import settings


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
