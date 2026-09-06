"""Seller ↔ marketplace assignment and stall location helpers."""

from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SellerProfile
from app.services.marketplace_scope import resolve_marketplace_id

OTHER_CASABLANCA_MARKETS_SLUG = "other-casablanca-markets"


async def apply_marketplace_slug(
    session: AsyncSession,
    seller: SellerProfile,
    marketplace_slug: str | None,
) -> None:
    await apply_marketplace_selection(session, seller, marketplace_slug, None)


async def apply_marketplace_selection(
    session: AsyncSession,
    seller: SellerProfile,
    marketplace_slug: str | None,
    custom_marketplace_name: str | None,
) -> None:
    if marketplace_slug is None and custom_marketplace_name is None:
        return

    custom = (custom_marketplace_name or "").strip()
    if custom_marketplace_name is not None:
        seller.custom_marketplace_name = custom

    if custom:
        seller.marketplace_id = await resolve_marketplace_id(session, OTHER_CASABLANCA_MARKETS_SLUG)
        return

    slug = (marketplace_slug or "").strip()
    if not slug:
        seller.marketplace_id = None
        seller.custom_marketplace_name = ""
        return

    seller.custom_marketplace_name = ""
    seller.marketplace_id = await resolve_marketplace_id(session, slug)


def attach_marketplace_metadata(seller: SellerProfile) -> None:
    marketplace = getattr(seller, "marketplace", None)
    custom = (seller.custom_marketplace_name or "").strip()
    if custom:
        setattr(seller, "marketplace_slug", OTHER_CASABLANCA_MARKETS_SLUG if marketplace else None)
        setattr(seller, "marketplace_name", custom)
    elif marketplace:
        setattr(seller, "marketplace_slug", marketplace.slug)
        setattr(seller, "marketplace_name", marketplace.name)
    else:
        setattr(seller, "marketplace_slug", None)
        setattr(seller, "marketplace_name", None)


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
