"""Trust score and sender profile for community messages."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Review, SellerProfile, User, VerificationStatus
from app.schemas.community import CommunitySenderOut
from app.services.entitlements import has_plus_plus


async def compute_trust_score(session: AsyncSession, user: User) -> int:
    score = 30

    if user.email_verified_at is not None:
        score += 15

    if await has_plus_plus(session, user):
        score += 10

    age_days = (datetime.now(UTC) - user.created_at.replace(tzinfo=UTC)).days
    if age_days >= 30:
        score += 10

    seller = await session.scalar(
        select(SellerProfile).where(SellerProfile.user_id == user.id)
    )
    if seller is not None:
        if seller.verification_status == VerificationStatus.VERIFIED:
            score += 20
        avg_rating = await session.scalar(
            select(func.avg(Review.rating)).where(Review.seller_id == seller.id)
        )
        review_count = await session.scalar(
            select(func.count()).select_from(Review).where(Review.seller_id == seller.id)
        )
        if review_count and review_count >= 3 and avg_rating and float(avg_rating) >= 4.0:
            score += 15

    return min(score, 100)


async def sender_profile(session: AsyncSession, user: User) -> CommunitySenderOut:
    seller = await session.scalar(
        select(SellerProfile).where(SellerProfile.user_id == user.id)
    )
    badges: list[str] = []
    is_verified = False
    role = user.role.value if hasattr(user.role, "value") else str(user.role)

    if seller is not None:
        role = "seller"
        if seller.verification_status == VerificationStatus.VERIFIED:
            is_verified = True
            badges.append("verified")
        if seller.golden_crowns and seller.golden_crowns > 0:
            badges.append("elite")

    plus_active = await has_plus_plus(session, user)
    if plus_active:
        badges.append("plus_plus")

    if user.email_verified_at is not None:
        badges.append("email_verified")

    trust = await compute_trust_score(session, user)
    if trust >= 80:
        badges.append("trusted")

    display_name = seller.business_name if seller and seller.business_name else user.display_name
    avatar_url = seller.logo_image_url if seller and seller.logo_image_url else ""

    return CommunitySenderOut(
        id=user.id,
        display_name=display_name or "Dribex User",
        avatar_url=avatar_url or "",
        role=role,
        is_premium=plus_active,
        show_plus_badge=plus_active,
        is_verified=is_verified,
        trust_score=trust,
        badges=badges,
    )
