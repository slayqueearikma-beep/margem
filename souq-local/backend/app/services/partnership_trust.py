"""Trust metrics and public partnership summaries."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import SellerProfile, VerificationStatus
from app.models.partnership import Partnership, PartnershipMember, PartnershipStatus


async def compute_joint_trust_score(session: AsyncSession, partnership_id: UUID) -> float:
    result = await session.execute(
        select(SellerProfile.average_rating)
        .join(PartnershipMember, PartnershipMember.seller_id == SellerProfile.id)
        .where(
            PartnershipMember.partnership_id == partnership_id,
            PartnershipMember.is_active.is_(True),
        )
    )
    ratings = [float(r) for r in result.scalars().all() if r is not None]
    if not ratings:
        return 0.0
    return round(sum(ratings) / len(ratings), 2)


async def partnership_duration_days(partnership: Partnership) -> int:
    start = partnership.start_date
    end = partnership.end_date or datetime.now(UTC)
    if start.tzinfo is None:
        start = start.replace(tzinfo=UTC)
    if end.tzinfo is None:
        end = end.replace(tzinfo=UTC)
    return max(0, (end - start).days)


async def is_partnership_verified(session: AsyncSession, partnership: Partnership) -> bool:
    if partnership.is_verified:
        return True
    if partnership.status != PartnershipStatus.ACTIVE:
        return False
    if partnership.requires_admin_approval and partnership.admin_approved_at is None:
        return False
    members = await session.execute(
        select(SellerProfile.verification_status)
        .join(PartnershipMember, PartnershipMember.seller_id == SellerProfile.id)
        .where(
            PartnershipMember.partnership_id == partnership.id,
            PartnershipMember.is_active.is_(True),
        )
    )
    statuses = list(members.scalars().all())
    if len(statuses) < 2:
        return False
    return all(s == VerificationStatus.VERIFIED for s in statuses)


async def load_partnership_with_members(session: AsyncSession, partnership_id: UUID) -> Partnership | None:
    result = await session.execute(
        select(Partnership)
        .where(Partnership.id == partnership_id)
        .options(
            selectinload(Partnership.members).selectinload(PartnershipMember.seller),
        )
    )
    return result.scalar_one_or_none()


async def member_seller_summaries(partnership: Partnership) -> list[dict]:
    summaries: list[dict] = []
    for member in partnership.members:
        if not member.is_active:
            continue
        seller = member.seller
        summaries.append(
            {
                "seller_id": str(seller.id),
                "business_name": seller.business_name,
                "logo_image_url": seller.logo_image_url,
                "average_rating": seller.average_rating,
                "review_count": seller.review_count,
                "verification_status": seller.verification_status.value,
                "role": member.role.value,
            }
        )
    return summaries
