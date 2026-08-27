import asyncio
import logging
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
from sqlalchemy import select, text, update
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import settings
import app.database as database
from app.limiter import limiter
from app.logging_config import configure_logging
from app.middleware.admin_ip_guard import AdminIpGuardMiddleware
from app.middleware.admin_origin_guard import AdminOriginGuardMiddleware
from app.middleware.request_context import RequestContextMiddleware
from app.middleware.request_limits import RequestSizeLimitMiddleware
from app.middleware.security import SecurityHeadersMiddleware
from app.models import Marketplace, SubscriptionPlan
from app.routers import (
    ad_admin,
    admin_moderation,
    advertisements,
    auth,
    billing,
    bundles,
    catalog,
    community,
    discovery,
    geography,
    legal_acceptance,
    legal_pages,
    marketplace_admin,
    marketplace_community,
    marketplaces,
    local_media,
    media,
    privacy,
    qr,
    search,
    seller_ops,
    sellers,
    uploads,
)
from app.services.local_storage import media_root
from app.services.community_chat import ensure_all_city_communities, ensure_default_cities
from app.services.geography import ensure_geography_seeded, seed_morocco_cities_if_empty
from app.services.subscription_maintenance import run_subscription_maintenance
from app.telemetry import configure_telemetry

configure_logging(json_logs=settings.app_env in {"production", "prod"})
configure_telemetry()

_maintenance_logger = logging.getLogger("margem.subscription_maintenance")
_maintenance_interval_seconds = 3600


async def _subscription_maintenance_loop() -> None:
    while True:
        await asyncio.sleep(_maintenance_interval_seconds)
        try:
            async with database.SessionLocal() as session:
                touched = await run_subscription_maintenance(session)
                if touched:
                    _maintenance_logger.info(
                        "subscription_maintenance_completed touched=%s", touched
                    )
        except asyncio.CancelledError:
            raise
        except Exception:
            _maintenance_logger.exception("subscription_maintenance_failed")

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
                        name="Dribex Plus+",
                        description="Buyer subscription — suppress promotional ads and show Plus+ badge.",
                        price_mad=50,
                        billing_period_days=30,
                        features=[
                            "promotional_ads_suppressed",
                            "plus_plus_badge",
                            "saved_searches_sync",
                            "priority_support",
                        ],
                    ),
                    SubscriptionPlan(
                        id=uuid4(),
                        code="seller_pro",
                        name="DriverPro",
                        description="Seller subscription — ad-free access, up to 20 combined products/services, and video uploads.",
                        price_mad=149,
                        billing_period_days=30,
                        features=[
                            "promotional_ads_suppressed",
                            "combined_listing_limit_20",
                            "video_uploads",
                            "featured_placement",
                            "premium_badge",
                        ],
                    ),
                ]
            )
            await session.commit()

    async with database.SessionLocal() as session:
        await session.execute(
            update(Marketplace)
            .where(Marketplace.slug == "9ri3a", Marketplace.name == "9ri3a")
            .values(name="Al Qurayaa")
        )
        await session.execute(
            update(SubscriptionPlan)
            .where(SubscriptionPlan.code == "buyer_premium")
            .values(
                name="Dribex Plus+",
                price_mad=50,
                description="Buyer subscription — suppress promotional ads and show Plus+ badge.",
                features=[
                    "promotional_ads_suppressed",
                    "plus_plus_badge",
                    "saved_searches_sync",
                    "priority_support",
                ],
            )
        )
        await session.execute(
            update(SubscriptionPlan)
            .where(SubscriptionPlan.code == "seller_pro")
            .values(
                name="DriverPro",
                price_mad=149,
                description="Seller subscription — ad-free access, up to 20 combined products/services, and video uploads.",
                features=[
                    "promotional_ads_suppressed",
                    "combined_listing_limit_20",
                    "video_uploads",
                    "featured_placement",
                    "premium_badge",
                ],
            )
        )
        await session.commit()

    async with database.SessionLocal() as session:
        await seed_morocco_cities_if_empty(session)
        await ensure_geography_seeded(session)
        await ensure_default_cities(session)
        await ensure_all_city_communities(session)

    if settings.effective_storage_provider == "selfhosted" and settings.minio_endpoint:
        try:
            from app.services.minio_storage import ensure_buckets

            ensure_buckets()
        except Exception:
            logging.getLogger("margem.storage").exception("minio_bucket_init_failed")

    try:
        async with database.SessionLocal() as session:
            await run_subscription_maintenance(session)
    except Exception:
        _maintenance_logger.exception("subscription_maintenance_startup_failed")

    maintenance_task = asyncio.create_task(_subscription_maintenance_loop())
    try:
        yield
    finally:
        maintenance_task.cancel()
        try:
            await maintenance_task
        except asyncio.CancelledError:
            pass
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
app.add_middleware(SlowAPIMiddleware)
app.add_middleware(RequestContextMiddleware)
app.add_middleware(RequestSizeLimitMiddleware)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(AdminIpGuardMiddleware)
app.add_middleware(AdminOriginGuardMiddleware)

if settings.allowed_hosts != ["*"] and settings.app_env not in {"development", "dev"}:
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
if settings.effective_storage_provider == "selfhosted":
    app.include_router(media.router)
app.include_router(discovery.router)
app.include_router(qr.router)
app.include_router(search.router)
app.include_router(seller_ops.router)
app.include_router(billing.router)
app.include_router(community.router)
app.include_router(marketplaces.router)
app.include_router(marketplace_community.router)
app.include_router(marketplace_admin.router)
app.include_router(bundles.router)
app.include_router(geography.router)
app.include_router(legal_acceptance.router)
app.include_router(legal_acceptance.auth_legal_router)
app.include_router(legal_pages.router)
app.include_router(privacy.router)
app.include_router(admin_moderation.router)
app.include_router(advertisements.router)
app.include_router(ad_admin.router)

if settings.serve_embedded_admin and _admin_dashboard_dir is not None:
    app.mount(
        "/admin",
        StaticFiles(directory=str(_admin_dashboard_dir), html=True),
        name="admin-dashboard",
    )

if settings.effective_storage_provider == "local":
    app.include_router(local_media.router)

_brand_dir = Path(__file__).resolve().parents[1] / "static" / "brand"
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


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", None) or request.headers.get("x-request-id") or str(uuid4())


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    from fastapi.encoders import jsonable_encoder

    request_id = _request_id(request)
    if settings.app_env in {"production", "prod"} and not settings.debug:
        return JSONResponse(
            status_code=422,
            content={
                "detail": "Validation error",
                "request_id": request_id,
            },
            headers={"X-Request-ID": request_id},
        )

    return JSONResponse(
        status_code=422,
        content={
            "detail": jsonable_encoder(exc.errors()),
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
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
    return {"status": "ok"}


@app.get("/ready")
@limiter.exempt
async def ready(request: Request):
    checks: dict[str, str] = {}
    db_ok = True
    try:
        async with database.engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            row = await conn.execute(
                text("SELECT to_regclass('public.users') IS NOT NULL AS exists")
            )
            schema_ready = row.scalar()
            checks["schema"] = "ok" if schema_ready else "missing"
    except Exception:
        db_ok = False
        checks["database"] = "error"

    if db_ok:
        checks["database"] = "ok"

    if settings.effective_storage_provider == "local":
        media_status = "ok"
        try:
            root = media_root()
            root.mkdir(parents=True, exist_ok=True)
            probe = root / ".writable_probe"
            probe.write_text("ok", encoding="utf-8")
            probe.unlink(missing_ok=True)
        except OSError:
            media_status = "error"
        checks["media"] = media_status

    if settings.serve_embedded_admin:
        checks["admin_dashboard"] = "ok" if _admin_dashboard_dir is not None else "missing"
    else:
        checks["admin_dashboard"] = "external"

    unhealthy = (
        checks.get("database") == "error"
        or checks.get("media") == "error"
        or checks.get("schema") == "missing"
    )
    if unhealthy:
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable", **checks},
        )
    return {"status": "ok", **checks}


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


@app.get("/metrics")
@limiter.exempt
async def metrics(request: Request):
    """Prometheus text metrics — internal/admin network only."""
    from fastapi.responses import JSONResponse, PlainTextResponse

    from app.services.client_ip import is_internal_network_access
    from app.telemetry import metrics_prometheus_text

    if not is_internal_network_access(request):
        return JSONResponse(status_code=403, content={"detail": "Metrics access denied"})
    return PlainTextResponse(metrics_prometheus_text(), media_type="text/plain; version=0.0.4")
