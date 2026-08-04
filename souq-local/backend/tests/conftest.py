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
        # Legacy tables from other branches/migrations may reference core tables.
        await conn.execute(
            text(
                """
                DO $$ DECLARE r RECORD;
                BEGIN
                    FOR r IN (
                        SELECT tablename
                        FROM pg_tables
                        WHERE schemaname = 'public'
                    ) LOOP
                        EXECUTE 'DROP TABLE IF EXISTS '
                            || quote_ident(r.tablename)
                            || ' CASCADE';
                    END LOOP;
                END $$;
                """
            )
        )
        await conn.run_sync(Base.metadata.create_all)

    async with database.SessionLocal() as session:
        session.add_all(
            [
                SubscriptionPlan(
                    id=uuid4(),
                    code="buyer_premium",
                    name="MarGem Plus",
                    description="Personalized discovery",
                    price_mad=49,
                    billing_period_days=30,
                    features=["Personalized recommendations", "Priority support"],
                ),
                SubscriptionPlan(
                    id=uuid4(),
                    code="seller_pro",
                    name="Seller Pro",
                    description="Seller visibility boost",
                    price_mad=199,
                    billing_period_days=30,
                    features=["Featured placement", "Analytics", "Premium badge"],
                ),
            ]
        )
        from app.models.geography import City, Country
        from app.services.geography import ensure_geography_seeded

        morocco = Country(
            id=uuid4(),
            code="MA",
            name_en="Morocco",
            name_ar="المغرب",
            name_fr="Maroc",
            is_active=True,
        )
        session.add(morocco)
        await session.flush()
        session.add_all(
            [
                City(
                    id=uuid4(),
                    country_id=morocco.id,
                    slug="casablanca",
                    name_en="Casablanca",
                    name_fr="Casablanca",
                    name_ar="الدار البيضاء",
                    region="Casablanca-Settat",
                    latitude=33.5731,
                    longitude=-7.5898,
                    is_active=True,
                    sort_order=1,
                ),
                City(
                    id=uuid4(),
                    country_id=morocco.id,
                    slug="rabat",
                    name_en="Rabat",
                    name_fr="Rabat",
                    name_ar="الرباط",
                    region="Rabat-Salé-Kénitra",
                    latitude=34.0209,
                    longitude=-6.8416,
                    is_active=True,
                    sort_order=2,
                ),
            ]
        )
        await session.commit()
        await ensure_geography_seeded(session)

    yield
    async with database.engine.begin() as conn:
        for table in (
            "admin_audit_logs",
            "subscriptions",
            "subscription_plans",
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
            "cities",
            "countries",
        ):
            await conn.execute(text(f"DELETE FROM {table}"))
    await database.engine.dispose()
