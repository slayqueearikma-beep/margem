"""Restrict admin API paths to configured IP ranges (home/LAN hardening)."""

from __future__ import annotations

import logging
from ipaddress import ip_address, ip_network

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import settings
from app.services.client_ip import get_client_ip

logger = logging.getLogger("margem.security")

_ADMIN_MARKERS = ("/admin/",)


def _is_admin_path(path: str) -> bool:
    return any(marker in path for marker in _ADMIN_MARKERS)


def _ip_permitted(ip: str, allowlist: list[str]) -> bool:
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


class AdminIpGuardMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if not settings.admin_ip_allowlist:
            return await call_next(request)
        if not _is_admin_path(request.url.path):
            return await call_next(request)

        client_ip = get_client_ip(request)
        if not _ip_permitted(client_ip, settings.admin_ip_allowlist):
            logger.warning(
                "admin_ip_denied ip=%s path=%s",
                client_ip,
                request.url.path,
            )
            return JSONResponse(
                status_code=403,
                content={"detail": "Admin access is not permitted from this network"},
            )
        return await call_next(request)
