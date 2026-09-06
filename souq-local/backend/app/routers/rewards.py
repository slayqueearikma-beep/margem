"""Rewarded advertisement session and completion APIs."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import User
from app.services.rewarded_ads import (
    ALLOWED_REWARD_FEATURES,
    FEATURE_SAVED_SEARCH,
    complete_reward_session,
    create_reward_session,
    list_active_rewards,
    rewarded_ads_operational,
)

router = APIRouter(prefix="/rewards", tags=["rewards"])
platform_router = APIRouter(prefix="/platform", tags=["platform"])


class MonetizationStatusOut(BaseModel):
    payments_enabled: bool
    subscriptions_enabled: bool
    ads_enabled: bool
    rewarded_ads_enabled: bool
    billing_self_serve_enabled: bool


class RewardSessionCreateIn(BaseModel):
    feature_code: str = Field(max_length=64)


class RewardSessionOut(BaseModel):
    session_id: UUID
    feature_code: str
    session_token: str
    expires_at: datetime


class RewardCompleteIn(BaseModel):
    session_id: UUID
    session_token: str = Field(min_length=32, max_length=128)
    provider: str = Field(default="internal", max_length=32)
    provider_reward_id: str | None = Field(default=None, max_length=128)


class RewardGrantOut(BaseModel):
    feature_code: str
    active: bool
    expires_at: datetime | None


class RewardCompleteOut(BaseModel):
    feature_code: str
    expires_at: datetime


class RewardStatusOut(BaseModel):
    active_rewards: list[RewardGrantOut]
    available_features: list[str]


@platform_router.get("/monetization", response_model=MonetizationStatusOut)
async def monetization_status() -> MonetizationStatusOut:
    from app.services.billing_service import billing_self_serve_enabled

    return MonetizationStatusOut(
        payments_enabled=settings.payments_enabled,
        subscriptions_enabled=settings.subscriptions_enabled,
        ads_enabled=settings.ads_enabled,
        rewarded_ads_enabled=settings.rewarded_ads_enabled,
        billing_self_serve_enabled=billing_self_serve_enabled(),
    )


@router.get("/status", response_model=RewardStatusOut)
async def reward_status(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> RewardStatusOut:
    grants = await list_active_rewards(session, user.id)
    return RewardStatusOut(
        active_rewards=[
            RewardGrantOut(
                feature_code=grant.feature_code,
                active=grant.active,
                expires_at=grant.expires_at,
            )
            for grant in grants
        ],
        available_features=sorted(ALLOWED_REWARD_FEATURES),
    )


@router.post("/sessions", response_model=RewardSessionOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("20/minute")
async def start_reward_session(
    request: Request,
    payload: RewardSessionCreateIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> RewardSessionOut:
    if payload.feature_code not in ALLOWED_REWARD_FEATURES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported reward feature.")
    reward_session, token = await create_reward_session(
        session,
        user_id=user.id,
        feature_code=payload.feature_code,
    )
    await session.commit()
    return RewardSessionOut(
        session_id=reward_session.id,
        feature_code=reward_session.feature_code,
        session_token=token,
        expires_at=reward_session.expires_at,
    )


@router.post("/complete", response_model=RewardCompleteOut)
@limiter.limit("10/minute")
async def complete_reward(
    request: Request,
    payload: RewardCompleteIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> RewardCompleteOut:
    if payload.provider not in {"internal", "admob"}:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Unsupported reward provider.")
    grant = await complete_reward_session(
        session,
        user_id=user.id,
        session_id=payload.session_id,
        session_token=payload.session_token,
        provider=payload.provider,
        provider_reward_id=payload.provider_reward_id,
    )
    await session.commit()
    return RewardCompleteOut(feature_code=grant.feature_code, expires_at=grant.expires_at)


# Re-export feature constants for other modules.
SAVED_SEARCH_FEATURE = FEATURE_SAVED_SEARCH
