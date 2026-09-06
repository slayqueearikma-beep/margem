"""Opaque public share tokens for QR codes and deep links."""

from __future__ import annotations

import secrets
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Product, SellerProfile, ShareLink


def _generate_token() -> str:
    return secrets.token_urlsafe(16).replace("-", "").replace("_", "")[:20]


def public_qr_url(token: str) -> str:
    base = settings.qr_public_base_url.rstrip("/")
    return f"{base}/p/{token}"


async def get_or_create_share_link(
    session: AsyncSession,
    *,
    resource_type: str,
    resource_id: UUID,
) -> ShareLink:
    existing = await session.scalar(
        select(ShareLink).where(
            ShareLink.resource_type == resource_type,
            ShareLink.resource_id == resource_id,
            ShareLink.is_active.is_(True),
        )
    )
    if existing is not None:
        return existing

    for _ in range(5):
        token = _generate_token()
        stmt = (
            insert(ShareLink)
            .values(token=token, resource_type=resource_type, resource_id=resource_id)
            .on_conflict_do_nothing(index_elements=["token"])
            .returning(ShareLink)
        )
        row = (await session.execute(stmt)).scalar_one_or_none()
        if row is not None:
            return row

    raise RuntimeError("Could not allocate share token")


async def resolve_share_token(session: AsyncSession, token: str) -> dict | None:
    cleaned = (token or "").strip()
    if not cleaned or len(cleaned) > 32:
        return None

    link = await session.scalar(
        select(ShareLink).where(ShareLink.token == cleaned, ShareLink.is_active.is_(True))
    )
    if link is None:
        return None

    if link.resource_type == "seller":
        seller = await session.get(SellerProfile, link.resource_id)
        if seller is None or not seller.is_active:
            return None
        return {
            "type": "seller",
            "id": str(seller.id),
            "business_name": seller.business_name,
            "city": seller.city,
            "description": seller.description[:500] if seller.description else "",
            "logo_image_url": seller.logo_image_url or "",
        }

    if link.resource_type == "product":
        product = await session.get(Product, link.resource_id)
        if product is None or product.is_hidden or not product.is_available:
            return None
        return {
            "type": "product",
            "id": str(product.id),
            "seller_id": str(product.seller_id),
            "name": product.name,
            "description": (product.description or "")[:500],
            "image_url": product.image_url or "",
            "price_mad": float(product.price_mad) if product.price_mad is not None else None,
        }

    return None
