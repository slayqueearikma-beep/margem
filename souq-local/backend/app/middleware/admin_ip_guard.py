"""Restrict admin API paths to configured IP ranges."""

from __future__ import annotations

import logging
from ipaddress import ip_address, ip_network

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import settings
from app.services.client_ip import get_client_ip

logger = logging.getLogger("margem.security")


def _is_admin_path(path: str) -> bool:
    normalized = path.rstrip("/") or "/"
    return normalized == "/admin" or "/admin/" in path


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
        if not _is_admin_path(request.url.path):
            return await call_next(request)

        allowlist = settings.admin_ip_allowlist
        strict_env = settings.app_env in {"production", "prod", "staging", "preprod"}
        if not allowlist:
            if strict_env:
                logger.warning(
                    "admin_ip_denied path=%s reason=empty_allowlist_in_strict_env",
                    request.url.path,
                )
                return JSONResponse(
                    status_code=403,
                    content={"detail": "Admin access is not permitted from this network"},
                )
            return await call_next(request)

        client_ip = get_client_ip(request)
        if not _ip_permitted(client_ip, allowlist):
            logger.warning("admin_ip_denied ip=%s path=%s", client_ip, request.url.path)
            return JSONResponse(
                status_code=403,
                content={"detail": "Admin access is not permitted from this network"},
            )
        return await call_next(request)
