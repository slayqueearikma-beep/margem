"""Block browser admin API calls from unexpected web origins."""

from urllib.parse import urlparse

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.config import settings
from app.middleware.admin_paths import is_admin_protected_path


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
            if ref_origin and ref_origin.rstrip("/") not in allowed:
                return JSONResponse(
                    status_code=403,
                    content={"detail": "Admin API access denied for this origin"},
                )

        return await call_next(request)
