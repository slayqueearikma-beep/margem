from contextlib import asynccontextmanager
from uuid import uuid4

from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy import select, text
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import settings
import app.database as database
from app.limiter import limiter
from app.logging_config import configure_logging
from app.middleware.admin_origin_guard import AdminOriginGuardMiddleware
from app.middleware.request_context import RequestContextMiddleware
from app.middleware.request_limits import RequestSizeLimitMiddleware
from app.middleware.security import SecurityHeadersMiddleware
from app.models import SubscriptionPlan
from app.routers import (
    auth,
    bundles,
    catalog,
    community,
    discovery,
    marketplace_admin,
    marketplace_community,
    marketplaces,
    search,
    seller_ops,
    sellers,
    uploads,
)
from app.services.local_storage import media_root
from app.services.community_chat import ensure_default_cities
from app.telemetry import configure_telemetry

configure_logging(json_logs=settings.app_env in {"production", "prod"})
configure_telemetry()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ensure premium plans exist after migrations / fresh create_all environments.
    async with database.SessionLocal() as session:
        existing = await session.execute(select(SubscriptionPlan).limit(1))
        if existing.scalar_one_or_none() is None:
            session.add_all(
                [
                    SubscriptionPlan(
                        id=uuid4(),
                        code="buyer_premium",
                        name="MarGem Plus",
                        description="Saved searches, personalized recommendations, priority support",
                        price_mad=49,
                        billing_period_days=30,
                        features=[
                            "Saved searches sync",
                            "Personalized recommendations",
                            "Priority support",
                            "Early access to featured listings",
                        ],
                    ),
                    SubscriptionPlan(
                        id=uuid4(),
                        code="seller_pro",
                        name="Seller Pro",
                        description="Featured placement, premium storefront, advanced discovery analytics",
                        price_mad=199,
                        billing_period_days=30,
                        features=[
                            "Featured placement",
                            "Premium badge",
                            "Advanced analytics",
                            "Extra media uploads",
                            "Verification priority",
                        ],
                    ),
                ]
            )
            await session.commit()

    async with database.SessionLocal() as session:
        await ensure_default_cities(session)

    yield
    await database.engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug or settings.app_env == "development" else None,
    redoc_url=None,
    openapi_url="/openapi.json" if settings.debug or settings.app_env == "development" else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
# Outermost first for ProxyHeaders so TrustedHost/HSTS see the real scheme.
app.add_middleware(SlowAPIMiddleware)
app.add_middleware(RequestContextMiddleware)
app.add_middleware(RequestSizeLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(AdminOriginGuardMiddleware)

if settings.allowed_hosts != ["*"]:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    expose_headers=["X-Request-ID"],
    max_age=600,
)

# Only trust forwarded headers from known reverse-proxy hosts (or loopback in dev).
_proxy_trusted = (
    settings.allowed_hosts
    if settings.allowed_hosts != ["*"]
    else ["127.0.0.1", "localhost"]
)
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=_proxy_trusted)

app.include_router(auth.router)
app.include_router(catalog.router)
app.include_router(sellers.router)
app.include_router(uploads.router)
app.include_router(discovery.router)
app.include_router(search.router)
app.include_router(seller_ops.router)
app.include_router(community.router)
app.include_router(marketplaces.router)
app.include_router(marketplace_community.router)
app.include_router(marketplace_admin.router)
app.include_router(bundles.router)

_admin_dashboard_dir: Path | None = None
if settings.serve_embedded_admin:
    if settings.admin_dashboard_dir.strip():
        _candidate = Path(settings.admin_dashboard_dir).expanduser()
        if _candidate.is_dir():
            _admin_dashboard_dir = _candidate
    if _admin_dashboard_dir is None:
        for _candidate in (
            Path(__file__).resolve().parents[2] / "admin-dashboard",
            Path("/admin-dashboard"),
        ):
            if _candidate.is_dir():
                _admin_dashboard_dir = _candidate
                break
if _admin_dashboard_dir is not None:
    app.mount(
        "/admin",
        StaticFiles(directory=str(_admin_dashboard_dir), html=True),
        name="admin-dashboard",
    )

if settings.storage_backend == "local":
    app.mount(
        "/media",
        StaticFiles(directory=str(media_root())),
        name="media",
    )

_brand_dir = Path(__file__).resolve().parents[1] / "static" / "brand"
_legal_dir = Path(__file__).resolve().parents[1] / "static" / "legal"
if _brand_dir.is_dir():
    app.mount("/brand", StaticFiles(directory=str(_brand_dir)), name="brand")

    @app.get("/favicon.ico", include_in_schema=False)
    async def favicon() -> FileResponse:
        return FileResponse(_brand_dir / "favicon.ico")

    @app.get("/site.webmanifest", include_in_schema=False)
    async def web_manifest() -> FileResponse:
        manifest = _brand_dir / "site.webmanifest"
        if manifest.is_file():
            return FileResponse(manifest, media_type="application/manifest+json")
        return FileResponse(_brand_dir / "icon-192.png")


if _legal_dir.is_dir():
    app.mount("/legal", StaticFiles(directory=str(_legal_dir)), name="legal")

    @app.get("/terms", include_in_schema=False)
    async def terms_page() -> FileResponse:
        return FileResponse(_legal_dir / "terms.html")

    @app.get("/privacy", include_in_schema=False)
    async def privacy_page() -> FileResponse:
        return FileResponse(_legal_dir / "privacy.html")


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", None) or request.headers.get("x-request-id") or str(uuid4())


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    from fastapi.encoders import jsonable_encoder

    return JSONResponse(
        status_code=422,
        content={
            "detail": jsonable_encoder(exc.errors()),
            "request_id": _request_id(request),
        },
        headers={"X-Request-ID": _request_id(request)},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    import logging

    request_id = _request_id(request)
    logging.getLogger("margem.errors").exception(
        "unhandled_error request_id=%s path=%s", request_id, request.url.path
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


@app.get("/live")
@limiter.exempt
async def live(request: Request):
    """Process liveness — does not check dependencies."""
    return {"status": "ok"}


@app.get("/ready")
@limiter.exempt
async def ready(request: Request):
    """Readiness — fails when the database is unreachable."""
    try:
        async with database.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable", "database": "error"},
        )
    body: dict[str, str] = {"status": "ok", "database": "ok"}
    if _admin_dashboard_dir is not None:
        body["admin_dashboard"] = "ok"
    else:
        body["admin_dashboard"] = "missing"
    return body


@app.get("/health")
@limiter.exempt
async def health(request: Request):
    db_status = "ok"
    try:
        async with database.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "error"

    if db_status != "ok":
        body: dict[str, str] = {"status": "unavailable", "database": db_status}
        if settings.app_env in {"development", "dev"} or settings.debug:
            body["service"] = settings.app_name
            body["environment"] = settings.app_env
        return JSONResponse(status_code=503, content=body)

    body = {"status": "ok", "database": db_status}
    if settings.app_env in {"development", "dev"} or settings.debug:
        body["service"] = settings.app_name
        body["environment"] = settings.app_env
    return body
