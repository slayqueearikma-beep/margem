"""Admin moderation — discovery reports, community reports, privacy erasure requests."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import require_admin, require_staff
from app.database import get_db
from app.models import AdminAuditLog, PrivacyRequest, PrivacyRequestStatus, PrivacyRequestType, Report, User
from app.models.community import CommunityReport, CommunityReportStatus
from app.models.marketplace_community import MarketplaceCommunityReport, MarketplaceReportStatus
from app.services.account_deletion import delete_user_account
from app.services.audit import log_security_event

router = APIRouter(prefix="/admin", tags=["admin-moderation"])

DISCOVERY_REPORT_STATUSES = {"open", "under_review", "resolved", "rejected"}


class DiscoveryReportOut(BaseModel):
    id: str
    status: str
    reason: str
    details: str
    seller_id: str | None
    product_id: str | None
    reported_user_id: str | None
    reporter_id: str | None
    created_at: str
    updated_at: str | None
    resolution_notes: str


class ReportStatusUpdate(BaseModel):
    status: str = Field(max_length=32)
    resolution_notes: str = Field(default="", max_length=2000)


class PrivacyRequestAdminOut(BaseModel):
    id: str
    user_id: str
    user_email: str
    request_type: str
    status: str
    details: str
    resolution_notes: str
    created_at: str
    completed_at: str | None


class PrivacyRequestReview(BaseModel):
    status: PrivacyRequestStatus
    resolution_notes: str = Field(default="", max_length=4000)


def _discovery_report_out(row: Report) -> DiscoveryReportOut:
    return DiscoveryReportOut(
        id=str(row.id),
        status=row.status,
        reason=row.reason,
        details=row.details,
        seller_id=str(row.seller_id) if row.seller_id else None,
        product_id=str(row.product_id) if row.product_id else None,
        reported_user_id=str(row.reported_user_id) if row.reported_user_id else None,
        reporter_id=str(row.reporter_id) if row.reporter_id else None,
        created_at=row.created_at.isoformat(),
        updated_at=row.updated_at.isoformat() if getattr(row, "updated_at", None) else None,
        resolution_notes=getattr(row, "resolution_notes", "") or "",
    )


@router.get("/discovery/reports", response_model=list[DiscoveryReportOut])
async def list_discovery_reports(
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    status_filter: str = Query(default=""),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> list[DiscoveryReportOut]:
    stmt = select(Report).order_by(Report.created_at.desc()).offset(offset).limit(limit)
    if status_filter:
        if status_filter not in DISCOVERY_REPORT_STATUSES:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        stmt = stmt.where(Report.status == status_filter)
    rows = list((await session.execute(stmt)).scalars().all())
    return [_discovery_report_out(row) for row in rows]


@router.patch("/discovery/reports/{report_id}", response_model=DiscoveryReportOut)
async def update_discovery_report(
    report_id: UUID,
    payload: ReportStatusUpdate,
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> DiscoveryReportOut:
    if payload.status not in DISCOVERY_REPORT_STATUSES:
        raise HTTPException(status_code=400, detail="Invalid status")
    report = await session.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = payload.status
    report.resolution_notes = payload.resolution_notes.strip()
    report.reviewed_by_id = admin.id
    report.updated_at = datetime.now(UTC)
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="discovery_report_status",
            target_type="report",
            target_id=str(report_id),
            metadata_={"status": payload.status},
        )
    )
    await session.commit()
    await session.refresh(report)
    return _discovery_report_out(report)


@router.patch("/community/reports/{report_id}")
async def update_community_report(
    report_id: UUID,
    payload: ReportStatusUpdate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> dict:
    try:
        new_status = CommunityReportStatus(payload.status)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid status") from exc
    report = await session.get(CommunityReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = new_status
    report.reviewed_by_id = admin.id
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="community_report_status",
            target_type="community_report",
            target_id=str(report_id),
            metadata_={"status": new_status.value},
        )
    )
    await session.commit()
    return {"id": str(report.id), "status": report.status.value}


@router.patch("/marketplace-community/reports/{report_id}")
async def update_marketplace_community_report(
    report_id: UUID,
    payload: ReportStatusUpdate,
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> dict:
    try:
        new_status = MarketplaceReportStatus(payload.status)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid status") from exc
    report = await session.get(MarketplaceCommunityReport, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    report.status = new_status
    report.reviewed_by_id = admin.id
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="marketplace_community_report_status",
            target_type="marketplace_community_report",
            target_id=str(report_id),
            metadata_={"status": new_status.value},
        )
    )
    await session.commit()
    return {"id": str(report.id), "status": report.status.value}


@router.get("/privacy/requests", response_model=list[PrivacyRequestAdminOut])
async def list_privacy_requests_admin(
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    status_filter: str = Query(default=""),
    request_type: str = Query(default=""),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[PrivacyRequestAdminOut]:
    stmt = (
        select(PrivacyRequest, User.email)
        .join(User, User.id == PrivacyRequest.user_id)
        .order_by(PrivacyRequest.created_at.desc())
        .limit(limit)
    )
    if status_filter:
        stmt = stmt.where(PrivacyRequest.status == PrivacyRequestStatus(status_filter))
    if request_type:
        stmt = stmt.where(PrivacyRequest.request_type == PrivacyRequestType(request_type))
    rows = (await session.execute(stmt)).all()
    return [
        PrivacyRequestAdminOut(
            id=str(req.id),
            user_id=str(req.user_id),
            user_email=email,
            request_type=req.request_type.value,
            status=req.status.value,
            details=req.details,
            resolution_notes=req.resolution_notes,
            created_at=req.created_at.isoformat(),
            completed_at=req.completed_at.isoformat() if req.completed_at else None,
        )
        for req, email in rows
    ]


@router.patch("/privacy/requests/{request_id}", response_model=PrivacyRequestAdminOut)
async def review_privacy_request(
    request_id: UUID,
    payload: PrivacyRequestReview,
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> PrivacyRequestAdminOut:
    result = await session.execute(
        select(PrivacyRequest, User.email, User.status).where(PrivacyRequest.id == request_id).join(
            User, User.id == PrivacyRequest.user_id
        )
    )
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Request not found")
    req, user_email, _user_status = row
    if req.status in {PrivacyRequestStatus.COMPLETED, PrivacyRequestStatus.CANCELLED}:
        raise HTTPException(status_code=409, detail="Request already finalized")

    now = datetime.now(UTC)
    req.status = payload.status
    req.reviewer_id = admin.id
    req.resolution_notes = payload.resolution_notes.strip()
    if payload.status in {PrivacyRequestStatus.COMPLETED, PrivacyRequestStatus.REJECTED}:
        req.completed_at = now

    if (
        req.request_type == PrivacyRequestType.ERASURE
        and payload.status == PrivacyRequestStatus.COMPLETED
    ):
        from app.models import UserStatus

        target = await session.get(User, req.user_id)
        if target is not None and target.status != UserStatus.DELETED:
            await delete_user_account(session, target)
            req.resolution_notes = (
                req.resolution_notes or "Erasure completed via account deletion workflow."
            )
            user_email = target.email

    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="privacy_request_review",
            target_type="privacy_request",
            target_id=str(request_id),
            metadata_={"status": payload.status.value, "request_type": req.request_type.value},
        )
    )
    log_security_event(
        "privacy_request_reviewed",
        user_id=str(req.user_id),
        request_id=str(request_id),
        status=payload.status.value,
    )
    await session.commit()

    return PrivacyRequestAdminOut(
        id=str(req.id),
        user_id=str(req.user_id),
        user_email=user_email,
        request_type=req.request_type.value,
        status=req.status.value,
        details=req.details,
        resolution_notes=req.resolution_notes,
        created_at=req.created_at.isoformat(),
        completed_at=req.completed_at.isoformat() if req.completed_at else None,
    )
