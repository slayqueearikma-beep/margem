import os

# Must be set before app imports so Settings picks them up.
os.environ["DATABASE_URL"] = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local",
)
os.environ["APP_ENV"] = "development"
os.environ["JWT_SECRET_KEY"] = "test-jwt-secret-key-minimum-32-characters-long"
os.environ["AUTH_RATE_LIMIT"] = "1000/minute"
os.environ["RATE_LIMIT"] = "1000/minute"
os.environ["AUTH_DEV_BYPASS"] = "false"
os.environ["DEBUG"] = "false"

import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool


@pytest_asyncio.fixture(autouse=True)
async def prepare_database():
    """Recreate the async engine per test so connections bind to the active event loop."""
    import app.database as database
    from app.config import settings
    from app.models import Base, SubscriptionPlan
    from uuid import uuid4

    await database.engine.dispose()
    database.engine = create_async_engine(settings.database_url, echo=False, poolclass=NullPool)
    database.SessionLocal = async_sessionmaker(
        database.engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with database.engine.begin() as conn:
        # Drop legacy ecommerce tables that may still exist from older migrations
        # before recreating the discovery-platform schema.
        for table in (
            "order_items",
            "orders",
            "cart_items",
            "wishlist_items",
            "buyer_addresses",
            "coupons",
        ):
            await conn.execute(text(f"DROP TABLE IF EXISTS {table} CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS orderstatus CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS paymentstatus CASCADE"))
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    async with database.SessionLocal() as session:
        from app.data.business_categories import BUSINESS_CATEGORIES
        from app.models import Category
        from tests.factories import set_category_ids

        set_category_ids([])

        session.add_all(
            [
                SubscriptionPlan(
                    id=uuid4(),
                    code="basic",
                    name="Basic",
                    description="Free forever",
                    price_mad=0,
                    price_mad_yearly=0,
                    billing_period_days=30,
                    tier_level=0,
                    sort_order=0,
                    trial_days=0,
                    features=["Business storefront", "Standard search visibility"],
                ),
                SubscriptionPlan(
                    id=uuid4(),
                    code="premium",
                    name="Premium",
                    description="Featured placement",
                    price_mad=199,
                    price_mad_yearly=1999,
                    billing_period_days=30,
                    tier_level=1,
                    sort_order=1,
                    trial_days=7,
                    features=["Featured placement", "Premium badge", "Analytics"],
                ),
                SubscriptionPlan(
                    id=uuid4(),
                    code="enterprise",
                    name="Enterprise",
                    description="Maximum visibility",
                    price_mad=499,
                    price_mad_yearly=3999,
                    billing_period_days=30,
                    tier_level=2,
                    sort_order=2,
                    trial_days=14,
                    features=["Top placement", "Dedicated support"],
                ),
            ]
        )
        category_rows = [
            Category(
                id=uuid4(),
                slug=cat.slug,
                name_en=cat.name_en,
                name_fr=cat.name_fr,
                name_ar=cat.name_ar,
                icon=cat.icon,
                accent_color=cat.accent_color,
                sort_order=cat.sort_order,
            )
            for cat in BUSINESS_CATEGORIES
        ]
        session.add_all(category_rows)
        await session.commit()
        set_category_ids([str(row.id) for row in category_rows])

    yield
    async with database.engine.begin() as conn:
        for table in (
            "admin_audit_logs",
            "subscriptions",
            "subscription_plans",
            "stripe_webhook_events",
            "contact_events",
            "reports",
            "recently_viewed",
            "saved_searches",
            "seller_follows",
            "favorites",
            "notifications",
            "messages",
            "conversations",
            "mfa_factors",
            "auth_tokens",
            "refresh_tokens",
            "reviews",
            "products",
            "services",
            "seller_categories",
            "seller_profiles",
            "warning_zones",
            "users",
            "categories",
        ):
            await conn.execute(text(f"DELETE FROM {table}"))
    await database.engine.dispose()


@pytest_asyncio.fixture
async def client():
    """Shared async HTTP client for API integration tests."""
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
