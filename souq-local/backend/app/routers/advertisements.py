"""Public platform advertisement feed."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user_optional
from app.database import get_db
from app.models import User
from app.schemas.advertisements import AdvertisementPublicOut
from app.services.platform_advertisements import list_active_advertisements

router = APIRouter(prefix="/ads", tags=["advertisements"])


@router.get("/active", response_model=list[AdvertisementPublicOut])
async def active_advertisements(
    limit: int = Query(default=5, ge=1, le=20),
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> list[AdvertisementPublicOut]:
    """Return active promotional ads unless the viewer has an ad-free subscription."""
    ads = await list_active_advertisements(session, user=user, limit=limit)
    return [AdvertisementPublicOut.model_validate(ad) for ad in ads]
