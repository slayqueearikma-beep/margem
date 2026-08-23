"""Optimized admin dashboard analytics queries."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Category, Product, Report, Review, SellerProfile, User, UserStatus, VerificationStatus


async def fetch_dashboard_counts(session: AsyncSession, *, now: datetime) -> dict:
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    row = (
        await session.execute(
            select(
                func.count(User.id).label("total_users"),
                func.count(User.id)
                .filter(User.status == UserStatus.ACTIVE)
                .label("active_users"),
                func.count(User.id).filter(User.created_at >= week_ago).label("new_users_7d"),
                func.count(SellerProfile.id).label("total_businesses"),
                func.count(SellerProfile.id)
                .filter(SellerProfile.verification_status == VerificationStatus.VERIFIED)
                .label("verified_businesses"),
                func.count(SellerProfile.id)
                .filter(SellerProfile.verification_status == VerificationStatus.PENDING)
                .label("pending_verifications"),
                func.count(Product.id).label("total_listings"),
                func.count(Product.id).filter(Product.is_featured.is_(True)).label("featured_listings"),
                func.count(Category.id).label("total_categories"),
                func.count(Review.id).label("total_reviews"),
                func.count(Report.id).filter(Report.status == "open").label("open_reports"),
                func.count(User.id)
                .filter(
                    User.is_premium.is_(True),
                    or_(User.premium_until.is_(None), User.premium_until >= now),
                )
                .label("premium_subscribers"),
            )
        )
    ).one()

    return {
        "total_users": int(row.total_users or 0),
        "active_users": int(row.active_users or 0),
        "new_users_7d": int(row.new_users_7d or 0),
        "total_businesses": int(row.total_businesses or 0),
        "verified_businesses": int(row.verified_businesses or 0),
        "pending_verifications": int(row.pending_verifications or 0),
        "total_listings": int(row.total_listings or 0),
        "featured_listings": int(row.featured_listings or 0),
        "total_categories": int(row.total_categories or 0),
        "total_reviews": int(row.total_reviews or 0),
        "open_reports": int(row.open_reports or 0),
        "premium_subscribers": int(row.premium_subscribers or 0),
    }


async def fetch_daily_growth(
    session: AsyncSession,
    *,
    model,
    now: datetime,
    days: int = 30,
) -> list[dict]:
    start = now - timedelta(days=days - 1)
    day_col = func.date_trunc("day", model.created_at)
    result = await session.execute(
        select(day_col.label("day"), func.count(model.id))
        .where(model.created_at >= datetime.combine(start.date(), datetime.min.time(), tzinfo=UTC))
        .group_by(day_col)
        .order_by(day_col)
    )
    counts_by_day = {
        (row.day.date() if hasattr(row.day, "date") else row.day): int(row[1])
        for row in result.all()
    }
    series: list[dict] = []
    for i in range(days):
        day = (now - timedelta(days=days - 1 - i)).date()
        series.append({"date": day.isoformat(), "count": counts_by_day.get(day, 0)})
    return series


async def fetch_monthly_growth(
    session: AsyncSession,
    *,
    model,
    now: datetime,
    months: int = 12,
) -> list[dict]:
    month_col = func.date_trunc("month", model.created_at)
    start = (now.replace(day=1) - timedelta(days=30 * (months - 1))).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    result = await session.execute(
        select(month_col.label("month"), func.count(model.id))
        .where(model.created_at >= start)
        .group_by(month_col)
        .order_by(month_col)
    )
    counts: dict[str, int] = {}
    for row in result.all():
        month_dt = row.month
        key = month_dt.strftime("%Y-%m") if hasattr(month_dt, "strftime") else str(month_dt)[:7]
        counts[key] = int(row[1])
    series: list[dict] = []
    cursor = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    for _ in range(months):
        key = cursor.strftime("%Y-%m")
        series.insert(0, {"month": key, "count": counts.get(key, 0)})
        cursor = (cursor - timedelta(days=1)).replace(day=1)
    return series
