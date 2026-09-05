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
os.environ["SIGNUP_OTP_VERIFY_RATE_LIMIT"] = "1000/minute"
os.environ["AUTH_DEV_BYPASS"] = "false"
os.environ["DEBUG"] = "false"
os.environ["ALLOW_MANUAL_BILLING"] = "true"
os.environ.setdefault("STORAGE_PROVIDER", "local")
os.environ.setdefault("PAYMENTS_ENABLED", "true")
os.environ.setdefault("SUBSCRIPTIONS_ENABLED", "true")
os.environ.setdefault("PAYMENT_PROVIDER", "manual")
os.environ.setdefault("REWARDED_ADS_ENABLED", "true")
os.environ.setdefault("ADS_ENABLED", "true")
os.environ.setdefault("REWARDED_AD_SIGNING_SECRET", "test-rewarded-ad-signing-secret-32chars")

import pytest_asyncio
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool


@pytest_asyncio.fixture(autouse=True)
async def prepare_database(request):
    """Recreate the async engine per test so connections bind to the active event loop."""
    if request.node.get_closest_marker("no_db"):
        yield
        return

    import app.database as database
    from app.config import settings
    from app.models import AdvertisingPackage, Base, SubscriptionPlan
    from uuid import uuid4

    await database.engine.dispose()
    database.engine = create_async_engine(settings.database_url, echo=False, poolclass=NullPool)
    database.SessionLocal = async_sessionmaker(
        database.engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with database.engine.begin() as conn:
        for table in (
            "subscription_agreement_records",
            "advertising_campaigns",
            "dribex_service_payments",
            "payment_webhook_events",
            "advertising_packages",
            "order_items",
            "orders",
            "cart_items",
            "wishlist_items",
            "buyer_addresses",
            "coupons",
            "community_reports",
            "community_message_reactions",
            "community_messages",
            "community_channels",
            "community_memberships",
            "community_user_blocks",
            "community_user_mutes",
            "cities",
            "countries",
            "signup_verifications",
        ):
            await conn.execute(text(f"DROP TABLE IF EXISTS {table} CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS orderstatus CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS paymentstatus CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS platformpaymentstatus CASCADE"))
        await conn.execute(text("DROP TYPE IF EXISTS advertisingcampaignstatus CASCADE"))
        await conn.execute(text("DROP SCHEMA IF EXISTS public CASCADE"))
        await conn.execute(text("CREATE SCHEMA public"))
        await conn.execute(text("GRANT ALL ON SCHEMA public TO public"))
        await conn.run_sync(Base.metadata.create_all)

    async with database.SessionLocal() as session:
        existing = (
            await session.execute(
                select(SubscriptionPlan.code).where(
                    SubscriptionPlan.code.in_(["buyer_premium", "seller_pro"])
                )
            )
        ).scalars().all()
        seed_rows: list[object] = []
        if not existing:
            seed_rows.extend(
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
        existing_packages = (
            await session.execute(
                select(AdvertisingPackage.code).where(
                    AdvertisingPackage.code == "sponsored_listing_7d"
                )
            )
        ).scalar_one_or_none()
        if existing_packages is None:
            seed_rows.append(
                AdvertisingPackage(
                    id=uuid4(),
                    code="sponsored_listing_7d",
                    name="Sponsored listing (7 days)",
                    description="Promote storefront",
                    placement_type="sponsored_listing",
                    price_mad=149,
                    duration_days=7,
                )
            )
        if seed_rows:
            session.add_all(seed_rows)
            await session.commit()

        from app.models.marketplace import Marketplace
        from app.services.seller_marketplace import OTHER_CASABLANCA_MARKETS_SLUG

        other_market = (
            await session.execute(
                select(Marketplace.id).where(Marketplace.slug == OTHER_CASABLANCA_MARKETS_SLUG)
            )
        ).scalar_one_or_none()
        if other_market is None:
            session.add(
                Marketplace(
                    id=uuid4(),
                    slug=OTHER_CASABLANCA_MARKETS_SLUG,
                    name="Other Casablanca Markets",
                    description="Casablanca commercial areas not yet listed as dedicated markets.",
                    known_for="User-provided market or district names",
                    address="Casablanca",
                    district="Casablanca",
                    city="Casablanca",
                    latitude=33.5731,
                    longitude=-7.5898,
                    display_order=99,
                    is_active=True,
                )
            )
            await session.commit()

        from app.services.community_chat import ensure_all_city_communities
        from app.services.geography import ensure_geography_seeded, seed_morocco_cities_if_empty

        await seed_morocco_cities_if_empty(session)
        await ensure_all_city_communities(session)
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
            "mfa_recovery_codes",
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
