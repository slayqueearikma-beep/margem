"""Seller ↔ marketplace assignment and stall location helpers."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SellerProfile
from app.services.marketplace_scope import resolve_marketplace_id


async def apply_marketplace_slug(
    session: AsyncSession,
    seller: SellerProfile,
    marketplace_slug: str | None,
) -> None:
    if marketplace_slug is None:
        return
    slug = marketplace_slug.strip()
    if not slug:
        seller.marketplace_id = None
        return
    seller.marketplace_id = await resolve_marketplace_id(session, slug)


def attach_marketplace_metadata(seller: SellerProfile) -> None:
    marketplace = getattr(seller, "marketplace", None)
    setattr(seller, "marketplace_slug", marketplace.slug if marketplace else None)
    setattr(seller, "marketplace_name", marketplace.name if marketplace else None)


def format_stall_location(seller: SellerProfile) -> str:
    """Human-readable stall location from seller-provided fields only."""
    lines: list[str] = []
    if seller.market_gallery:
        lines.append(f"Gallery: {seller.market_gallery}")
    if seller.shop_number:
        lines.append(f"Shop: {seller.shop_number}")
    if seller.market_floor:
        lines.append(f"Floor: {seller.market_floor}")
    if seller.market_zone:
        lines.append(f"Zone: {seller.market_zone}")
    if seller.market_street:
        lines.append(f"Street: {seller.market_street}")
    if seller.nearby_landmark:
        lines.append(f"Near: {seller.nearby_landmark}")
    return "\n".join(lines)
