"""Resolve marketplace scope for seller/search filters."""

from __future__ import annotations

from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.marketplace import Marketplace


async def resolve_marketplace_id(
    session: AsyncSession,
    slug: str | None,
    *,
    strict: bool = True,
) -> UUID | None:
    if not slug:
        return None
    marketplace_id = await session.scalar(
        select(Marketplace.id).where(Marketplace.slug == slug.strip()[:80])
    )
    if marketplace_id is None and strict:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marketplace not found")
    return marketplace_id
