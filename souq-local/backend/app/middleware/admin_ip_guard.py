"""Restrict admin API paths to configured IP ranges (home/LAN hardening)."""

from __future__ import annotations

import logging

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import settings
from app.middleware.admin_paths import is_admin_protected_path
from app.services.client_ip import get_client_ip, ip_permitted

logger = logging.getLogger("margem.security")


def _is_admin_path(path: str) -> bool:
    return is_admin_protected_path(path)


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
        if not ip_permitted(client_ip, allowlist):
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
