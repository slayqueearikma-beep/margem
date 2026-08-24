"""Block browser admin API calls from unexpected web origins."""

from urllib.parse import urlparse

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.config import settings
from app.middleware.admin_paths import is_admin_protected_path
from app.services.client_ip import get_client_ip, ip_permitted

_STRICT_ENVS = frozenset({"production", "prod", "staging", "preprod", "preview"})


def _origin_from_referer(referer: str) -> str | None:
    parsed = urlparse(referer.strip())
    if not parsed.scheme or not parsed.netloc:
        return None
    return f"{parsed.scheme}://{parsed.netloc}"


class AdminOriginGuardMiddleware(BaseHTTPMiddleware):
    """Reject cross-origin admin API calls unless Origin/Referer is in CORS_ORIGINS."""

    async def dispatch(self, request: Request, call_next):
        if not is_admin_protected_path(request.url.path):
            return await call_next(request)

        allowed = {o.rstrip("/") for o in settings.cors_origins}
        origin = (request.headers.get("origin") or "").strip()
        if origin:
            if origin.rstrip("/") not in allowed:
                return JSONResponse(
                    status_code=403,
                    content={"detail": "Admin API access denied for this origin"},
                )
            return await call_next(request)

        referer = (request.headers.get("referer") or "").strip()
        if referer:
            ref_origin = _origin_from_referer(referer)
            if ref_origin is None:
                if settings.app_env in _STRICT_ENVS:
                    return JSONResponse(
                        status_code=403,
                        content={"detail": "Admin API access denied for this origin"},
                    )
            elif ref_origin.rstrip("/") not in allowed:
                return JSONResponse(
                    status_code=403,
                    content={"detail": "Admin API access denied for this origin"},
                )
            else:
                return await call_next(request)

        if settings.app_env in _STRICT_ENVS:
            allowlist = settings.admin_ip_allowlist
            client_ip = get_client_ip(request)
            if allowlist and ip_permitted(client_ip, allowlist):
                return await call_next(request)
            return JSONResponse(
                status_code=403,
                content={"detail": "Admin API access denied without trusted origin"},
            )

        return await call_next(request)
