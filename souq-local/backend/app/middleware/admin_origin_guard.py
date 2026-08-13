"""Block browser admin API calls from unexpected web origins."""

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.config import settings
from app.middleware.admin_ip_guard import _is_admin_path


class AdminOriginGuardMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if not _is_admin_path(request.url.path):
            return await call_next(request)

        origin = request.headers.get("origin")
        if origin and origin.rstrip("/") not in {o.rstrip("/") for o in settings.cors_origins}:
            return JSONResponse(
                status_code=403,
                content={"detail": "Admin API access denied for this origin"},
            )
        return await call_next(request)
