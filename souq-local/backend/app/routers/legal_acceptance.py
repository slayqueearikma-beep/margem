"""Legal policy acceptance API."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.database import get_db
from app.models import User
from app.services.client_ip import get_client_ip
from app.services.legal_acceptance import (
    build_acceptance_status,
    get_pending_policy_ids,
    get_required_onboarding_policies,
    get_user_acceptances,
    record_policy_acceptances,
)

router = APIRouter(prefix="/legal", tags=["legal"])


class PolicyAcceptanceItem(BaseModel):
    policy_id: str = Field(min_length=1, max_length=64)


class LegalAcceptRequest(BaseModel):
    policies: list[PolicyAcceptanceItem] = Field(min_length=1, max_length=8)
    language: str = Field(default="en", max_length=8)
    acknowledged: bool = False

    @field_validator("acknowledged")
    @classmethod
    def must_acknowledge(cls, value: bool) -> bool:
        if not value:
            raise ValueError("acknowledged must be true")
        return value


class LegalAcceptanceStatusOut(BaseModel):
    required: list[dict]
    pending: list[str]
    accepted: list[dict]
    complete: bool


@router.get("/accept/status", response_model=LegalAcceptanceStatusOut)
async def legal_acceptance_status(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> LegalAcceptanceStatusOut:
    accepted = await get_user_acceptances(session, user.id)
    pending = await get_pending_policy_ids(session, user.id)
    payload = build_acceptance_status(accepted_versions=accepted, pending_ids=pending)
    return LegalAcceptanceStatusOut(**payload)


@router.post("/accept", response_model=LegalAcceptanceStatusOut)
async def accept_legal_policies(
    payload: LegalAcceptRequest,
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> LegalAcceptanceStatusOut:
    if not payload.acknowledged:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Explicit acknowledgement is required",
        )

    required_ids = {p.policy_id for p in get_required_onboarding_policies()}
    submitted_ids = [item.policy_id for item in payload.policies]
    if set(submitted_ids) != required_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="All required policies must be accepted together",
        )

    client_ip = get_client_ip(request)
    user_agent = request.headers.get("user-agent", "")

    await record_policy_acceptances(
        session,
        user_id=user.id,
        policy_ids=submitted_ids,
        language=payload.language,
        ip_address=client_ip,
        user_agent=user_agent,
        source="onboarding_legal_accept",
        authentication_method="bearer_session",
    )
    await session.commit()

    accepted = await get_user_acceptances(session, user.id)
    pending = await get_pending_policy_ids(session, user.id)
    status_payload = build_acceptance_status(accepted_versions=accepted, pending_ids=pending)
    return LegalAcceptanceStatusOut(**status_payload)
