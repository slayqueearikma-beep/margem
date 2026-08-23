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
        # Reset schema when legacy/migration tables exist outside ORM metadata.
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        await conn.execute(text("CREATE SCHEMA public"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO public"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO souq"))
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
        await session.commit()

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
        ):
            await conn.execute(text(f"DELETE FROM {table}"))
    await database.engine.dispose()
