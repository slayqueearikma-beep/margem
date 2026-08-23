"""Find optimal multi-seller product combinations for bundle slots."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import PricingType, Product, SellerProfile, VerificationStatus
from app.schemas.bundle import (
    BundlePickOut,
    BundleResolveIn,
    BundleResolveOut,
    BundleResolveSlotIn,
    BundleSellerBreakdownOut,
)


def _escaped(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _warranty_label(*, product_note: str, seller_verified: bool) -> str:
    note = (product_note or "").strip()
    if note:
        return note
    if seller_verified:
        return "Verified seller — ask for warranty details"
    return "Contact seller for warranty"


def _score_candidate(
    *,
    price: float,
    max_price: float,
    seller_rating: float,
    seller_verified: bool,
) -> float:
    if max_price <= 0:
        normalized_price = 0.0
    else:
        normalized_price = min(price / max_price, 1.0)
    rating_component = min(max(seller_rating, 0.0) / 5.0, 1.0)
    verified_bonus = 0.08 if seller_verified else 0.0
    # Lower price is better; higher rating is better.
    return round((0.55 * (1.0 - normalized_price)) + (0.35 * rating_component) + verified_bonus, 4)


async def _slot_candidates(
    session: AsyncSession,
    *,
    marketplace_id: UUID,
    slot: BundleResolveSlotIn,
    min_seller_rating: float,
) -> list[tuple[Product, SellerProfile]]:
    stmt = (
        select(Product, SellerProfile)
        .join(SellerProfile, Product.seller_id == SellerProfile.id)
        .where(
            SellerProfile.is_active.is_(True),
            SellerProfile.marketplace_id == marketplace_id,
            Product.is_hidden.is_(False),
            Product.is_available.is_(True),
            Product.is_paused.is_(False),
            Product.pricing_type == PricingType.FIXED,
            Product.price_mad.is_not(None),
            SellerProfile.average_rating >= min_seller_rating,
        )
    )
    if slot.category_slug:
        stmt = stmt.where(Product.category_slug == slot.category_slug[:80])
    if slot.query:
        pattern = f"%{_escaped(slot.query.strip()[:80])}%"
        stmt = stmt.where(
            or_(
                Product.name.ilike(pattern),
                Product.description.ilike(pattern),
            )
        )
    rows = list((await session.execute(stmt.options(selectinload(SellerProfile.user)))).all())
    return [(product, seller) for product, seller in rows]


def _reference_price(prices: list[float]) -> float:
    if not prices:
        return 0.0
    if len(prices) == 1:
        return prices[0]
    # Use average of top 3 prices as a retail reference for savings display.
    top = sorted(prices, reverse=True)[:3]
    return round(sum(top) / len(top), 2)


async def resolve_bundle(
    session: AsyncSession,
    *,
    marketplace_slug: str,
    marketplace_id: UUID,
    payload: BundleResolveIn,
) -> BundleResolveOut:
    picks: list[BundlePickOut] = []
    missing_slots: list[str] = []

    for slot in payload.slots:
        candidates = await _slot_candidates(
            session,
            marketplace_id=marketplace_id,
            slot=slot,
            min_seller_rating=payload.min_seller_rating,
        )
        if not candidates:
            missing_slots.append(slot.key)
            continue

        prices = [float(product.price_mad) for product, _ in candidates if product.price_mad is not None]
        max_price = max(prices) if prices else 0.0
        reference_price = _reference_price(prices)

        best: tuple[Product, SellerProfile, float] | None = None
        for product, seller in candidates:
            price = float(product.price_mad or 0)
            score = _score_candidate(
                price=price,
                max_price=max_price,
                seller_rating=float(seller.average_rating or 0),
                seller_verified=seller.verification_status == VerificationStatus.VERIFIED,
            )
            if best is None or score > best[2] or (score == best[2] and price < float(best[0].price_mad or 0)):
                best = (product, seller, score)

        assert best is not None
        product, seller, score = best
        picks.append(
            BundlePickOut(
                slot_key=slot.key,
                slot_label=slot.label,
                product_id=product.id,
                product_name=product.name,
                price_mad=float(product.price_mad or 0),
                image_url=product.image_url or "",
                category_slug=product.category_slug or "",
                is_available=product.is_available and not product.is_paused,
                stock_quantity=int(product.stock_quantity or 0),
                availability_note=product.availability_note or "",
                warranty_note=_warranty_label(
                    product_note=getattr(product, "warranty_note", "") or "",
                    seller_verified=seller.verification_status == VerificationStatus.VERIFIED,
                ),
                seller_id=seller.id,
                seller_name=seller.business_name,
                seller_verified=seller.verification_status == VerificationStatus.VERIFIED,
                seller_rating=float(seller.average_rating or 0),
                value_score=score,
                reference_price_mad=reference_price,
            )
        )

    total_price = round(sum(pick.price_mad for pick in picks), 2)
    reference_total = round(sum(pick.reference_price_mad for pick in picks), 2)
    savings = round(max(reference_total - total_price, 0.0), 2)
    savings_percent = round((savings / reference_total) * 100, 1) if reference_total > 0 else 0.0

    breakdown_map: dict[UUID, BundleSellerBreakdownOut] = {}
    for pick in picks:
        existing = breakdown_map.get(pick.seller_id)
        if existing is None:
            breakdown_map[pick.seller_id] = BundleSellerBreakdownOut(
                seller_id=pick.seller_id,
                seller_name=pick.seller_name,
                seller_verified=pick.seller_verified,
                seller_rating=pick.seller_rating,
                subtotal_mad=pick.price_mad,
                item_count=1,
                warranty_summary=pick.warranty_note,
                items=[pick],
            )
            continue
        existing.items.append(pick)
        existing.item_count += 1
        existing.subtotal_mad = round(existing.subtotal_mad + pick.price_mad, 2)
        if pick.warranty_note not in existing.warranty_summary:
            existing.warranty_summary = f"{existing.warranty_summary}; {pick.warranty_note}"

    seller_breakdown = sorted(breakdown_map.values(), key=lambda row: row.seller_name.lower())

    return BundleResolveOut(
        marketplace=marketplace_slug,
        template_slug=payload.template_slug,
        slots_requested=len(payload.slots),
        slots_matched=len(picks),
        total_price_mad=total_price,
        reference_price_mad=reference_total,
        savings_mad=savings,
        savings_percent=savings_percent,
        all_available=all(pick.is_available and pick.stock_quantity > 0 for pick in picks),
        picks=picks,
        missing_slots=missing_slots,
        seller_breakdown=seller_breakdown,
    )
