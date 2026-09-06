"""Privacy rights and consent management API (Morocco Law 09-08)."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.database import get_db
from app.limiter import limiter
from app.models import PrivacyRequestType, User
from app.services.privacy_compliance import (
    CONSENT_DEFINITIONS,
    create_privacy_request,
    get_latest_consents,
    get_user_privacy_request,
    list_consent_history,
    list_user_privacy_requests,
    record_user_consent,
)

router = APIRouter(prefix="/privacy", tags=["privacy"])


class ConsentUpdateRequest(BaseModel):
    granted: bool
    language: str = Field(default="en", max_length=8)


class ConsentStateOut(BaseModel):
    consent_type: str
    granted: bool
    purpose: str
    legal_basis: str


class ConsentHistoryItemOut(BaseModel):
    consent_type: str
    granted: bool
    purpose: str
    policy_version: str
    language: str
    source: str
    recorded_at: str
    withdrawn_at: str | None


class PrivacyRequestCreate(BaseModel):
    request_type: PrivacyRequestType
    details: str = Field(default="", max_length=4000)


class PrivacyRequestOut(BaseModel):
    id: str
    request_type: str
    status: str
    details: str
    resolution_notes: str
    created_at: str
    completed_at: str | None


def _request_out(row) -> PrivacyRequestOut:
    return PrivacyRequestOut(
        id=str(row.id),
        request_type=row.request_type.value,
        status=row.status.value,
        details=row.details,
        resolution_notes=row.resolution_notes,
        created_at=row.created_at.isoformat(),
        completed_at=row.completed_at.isoformat() if row.completed_at else None,
    )


@router.get("/consents", response_model=list[ConsentStateOut])
async def get_consent_state(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[ConsentStateOut]:
    latest = await get_latest_consents(session, user.id)
    return [
        ConsentStateOut(
            consent_type=consent_type,
            granted=latest.get(consent_type, False),
            purpose=meta["purpose"],
            legal_basis=meta["legal_basis"],
        )
        for consent_type, meta in CONSENT_DEFINITIONS.items()
    ]


@router.get("/consents/history", response_model=list[ConsentHistoryItemOut])
async def get_consent_history(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[ConsentHistoryItemOut]:
    rows = await list_consent_history(session, user.id)
    return [
        ConsentHistoryItemOut(
            consent_type=row.consent_type,
            granted=row.granted,
            purpose=row.purpose,
            policy_version=row.policy_version,
            language=row.language,
            source=row.source,
            recorded_at=row.recorded_at.isoformat(),
            withdrawn_at=row.withdrawn_at.isoformat() if row.withdrawn_at else None,
        )
        for row in rows
    ]


@router.put("/consents/{consent_type}")
@limiter.limit("30/minute")
async def update_consent(
    request: Request,
    consent_type: str,
    payload: ConsentUpdateRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ConsentStateOut:
    if consent_type not in CONSENT_DEFINITIONS:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown consent type")

    client_ip = request.client.host if request.client else ""
    user_agent = request.headers.get("user-agent", "")
    await record_user_consent(
        session,
        user_id=user.id,
        consent_type=consent_type,
        granted=payload.granted,
        language=payload.language,
        source="mobile_settings",
        ip_address=client_ip,
        user_agent=user_agent,
    )
    await session.commit()
    meta = CONSENT_DEFINITIONS[consent_type]
    return ConsentStateOut(
        consent_type=consent_type,
        granted=payload.granted,
        purpose=meta["purpose"],
        legal_basis=meta["legal_basis"],
    )


@router.get("/requests", response_model=list[PrivacyRequestOut])
async def list_privacy_requests(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[PrivacyRequestOut]:
    rows = await list_user_privacy_requests(session, user.id)
    return [_request_out(row) for row in rows]


@router.post("/requests", response_model=PrivacyRequestOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/hour")
async def submit_privacy_request(
    request: Request,
    payload: PrivacyRequestCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PrivacyRequestOut:
    client_ip = request.client.host if request.client else ""
    user_agent = request.headers.get("user-agent", "")
    row = await create_privacy_request(
        session,
        user_id=user.id,
        request_type=payload.request_type,
        details=payload.details,
        ip_address=client_ip,
        user_agent=user_agent,
    )
    await session.commit()
    return _request_out(row)


@router.get("/requests/{request_id}", response_model=PrivacyRequestOut)
async def get_privacy_request(
    request_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PrivacyRequestOut:
    row = await get_user_privacy_request(session, user.id, request_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    return _request_out(row)
