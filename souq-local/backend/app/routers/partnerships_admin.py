"""Admin partnership management."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import require_admin, require_staff
from app.database import get_db
from app.models import AdminAuditLog, User
from app.models.partnership import (
    Partnership,
    PartnershipAuditLog,
    PartnershipMember,
    PartnershipRevenueRecord,
    PartnershipStatus,
)
from app.services.partnership_trust import compute_joint_trust_score, is_partnership_verified

router = APIRouter(prefix="/admin/partnerships", tags=["admin-partnerships"])


class AdminPartnershipOut(BaseModel):
    id: UUID
    name: str
    status: PartnershipStatus
    partnership_type: str
    marketplace_slug: str
    member_count: int
    is_verified: bool
    requires_admin_approval: bool
    admin_approved_at: datetime | None
    successful_collaborations: int
    created_at: datetime


class AdminPartnershipDetail(AdminPartnershipOut):
    description: str
    category_slugs: list[str]
    members: list[dict]
    joint_trust_score: float


@router.get("", response_model=list[AdminPartnershipOut])
async def list_all_partnerships(
    status_filter: PartnershipStatus | None = Query(default=None, alias="status"),
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
):
    stmt = select(Partnership).options(selectinload(Partnership.members))
    if status_filter:
        stmt = stmt.where(Partnership.status == status_filter)
    stmt = stmt.order_by(Partnership.created_at.desc())
    result = await session.execute(stmt)
    partnerships = result.scalars().unique().all()
    out: list[AdminPartnershipOut] = []
    for p in partnerships:
        verified = await is_partnership_verified(session, p)
        out.append(
            AdminPartnershipOut(
                id=p.id,
                name=p.name,
                status=p.status,
                partnership_type=p.partnership_type.value,
                marketplace_slug=p.marketplace_slug,
                member_count=sum(1 for m in p.members if m.is_active),
                is_verified=verified,
                requires_admin_approval=p.requires_admin_approval,
                admin_approved_at=p.admin_approved_at,
                successful_collaborations=p.successful_collaborations,
                created_at=p.created_at,
            )
        )
    return out


@router.get("/{partnership_id}", response_model=AdminPartnershipDetail)
async def get_partnership_detail(
    partnership_id: UUID,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
):
    result = await session.execute(
        select(Partnership)
        .where(Partnership.id == partnership_id)
        .options(selectinload(Partnership.members).selectinload(PartnershipMember.seller))
    )
    partnership = result.scalar_one_or_none()
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    joint = await compute_joint_trust_score(session, partnership.id)
    verified = await is_partnership_verified(session, partnership)
    members = [
        {
            "seller_id": str(m.seller_id),
            "business_name": m.seller.business_name,
            "role": m.role.value,
            "is_active": m.is_active,
        }
        for m in partnership.members
    ]
    return AdminPartnershipDetail(
        id=partnership.id,
        name=partnership.name,
        status=partnership.status,
        partnership_type=partnership.partnership_type.value,
        marketplace_slug=partnership.marketplace_slug,
        member_count=sum(1 for m in partnership.members if m.is_active),
        is_verified=verified,
        requires_admin_approval=partnership.requires_admin_approval,
        admin_approved_at=partnership.admin_approved_at,
        successful_collaborations=partnership.successful_collaborations,
        created_at=partnership.created_at,
        description=partnership.description,
        category_slugs=partnership.category_slugs or [],
        members=members,
        joint_trust_score=joint,
    )


@router.post("/{partnership_id}/approve", status_code=status.HTTP_204_NO_CONTENT)
async def approve_partnership(
    partnership_id: UUID,
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
):
    partnership = await session.get(Partnership, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    partnership.admin_approved_at = datetime.now(UTC)
    partnership.admin_approved_by_id = user.id
    partnership.is_verified = True
    if partnership.status == PartnershipStatus.PENDING:
        partnership.status = PartnershipStatus.ACTIVE
    session.add(
        AdminAuditLog(
            actor_id=user.id,
            action="partnership.approved",
            target_type="partnership",
            target_id=str(partnership_id),
        )
    )
    await session.commit()


@router.post("/{partnership_id}/suspend", status_code=status.HTTP_204_NO_CONTENT)
async def suspend_partnership(
    partnership_id: UUID,
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
):
    partnership = await session.get(Partnership, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    partnership.status = PartnershipStatus.SUSPENDED
    session.add(
        AdminAuditLog(
            actor_id=user.id,
            action="partnership.suspended",
            target_type="partnership",
            target_id=str(partnership_id),
        )
    )
    await session.commit()


@router.post("/{partnership_id}/reactivate", status_code=status.HTTP_204_NO_CONTENT)
async def reactivate_partnership(
    partnership_id: UUID,
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
):
    partnership = await session.get(Partnership, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    partnership.status = PartnershipStatus.ACTIVE
    session.add(
        AdminAuditLog(
            actor_id=user.id,
            action="partnership.reactivated",
            target_type="partnership",
            target_id=str(partnership_id),
        )
    )
    await session.commit()


@router.get("/{partnership_id}/audit-log")
async def admin_partnership_audit(
    partnership_id: UUID,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=200, le=1000),
):
    result = await session.execute(
        select(PartnershipAuditLog)
        .where(PartnershipAuditLog.partnership_id == partnership_id)
        .order_by(PartnershipAuditLog.created_at.desc())
        .limit(limit)
    )
    return [
        {
            "id": str(e.id),
            "action": e.action,
            "actor_user_id": str(e.actor_user_id) if e.actor_user_id else None,
            "actor_seller_id": str(e.actor_seller_id) if e.actor_seller_id else None,
            "target_type": e.target_type,
            "target_id": e.target_id,
            "metadata": e.metadata_,
            "created_at": e.created_at.isoformat(),
        }
        for e in result.scalars().all()
    ]


@router.get("/{partnership_id}/revenue-records")
async def admin_revenue_records(
    partnership_id: UUID,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
):
    result = await session.execute(
        select(PartnershipRevenueRecord)
        .where(PartnershipRevenueRecord.partnership_id == partnership_id)
        .order_by(PartnershipRevenueRecord.created_at.desc())
    )
    return [
        {
            "id": str(r.id),
            "collaboration_id": str(r.collaboration_id) if r.collaboration_id else None,
            "total_amount_mad": float(r.total_amount_mad),
            "allocations": r.allocations,
            "created_at": r.created_at.isoformat(),
        }
        for r in result.scalars().all()
    ]
