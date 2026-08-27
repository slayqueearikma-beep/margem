"""Premium membership helpers — keep public flags consistent with subscription entitlements."""

from __future__ import annotations

from datetime import UTC, datetime

from app.models import SellerProfile, User


def is_premium_active(
    *,
    is_premium: bool,
    premium_until: datetime | None,
    now: datetime | None = None,
) -> bool:
    if not is_premium:
        return False
    if premium_until is None:
        return False
    clock = now or datetime.now(UTC)
    if premium_until.tzinfo is None:
        premium_until = premium_until.replace(tzinfo=UTC)
    return premium_until >= clock


def buyer_plus_active(user: User | None, *, now: datetime | None = None) -> bool:
    """Legacy sync helper — flags are synced from subscription records server-side."""
    if user is None:
        return False
    return is_premium_active(
        is_premium=bool(user.is_premium),
        premium_until=user.premium_until,
        now=now,
    )


def seller_pro_active(seller: SellerProfile, *, now: datetime | None = None) -> bool:
    """DriverPro storefront entitlement — synced from seller subscription records."""
    owner: User | None = getattr(seller, "user", None)
    premium_until = owner.premium_until if owner is not None else None
    return is_premium_active(
        is_premium=bool(seller.is_premium),
        premium_until=premium_until if seller.is_premium else None,
        now=now,
    )


def attach_premium_flags(seller: SellerProfile, *, persist: bool = False) -> bool:
    """Set is_seller_pro / is_buyer_plus on seller responses."""
    owner: User | None = getattr(seller, "user", None)
    now = datetime.now(UTC)
    seller_active = seller_pro_active(seller, now=now)
    buyer_active = buyer_plus_active(owner, now=now)

    if persist and owner is not None:
        if seller.is_premium and not seller_active:
            seller.is_premium = False
        if owner.is_premium and not buyer_active:
            owner.is_premium = False
    elif not persist:
        seller.is_premium = seller_active

    setattr(seller, "is_seller_pro", seller_active)
    setattr(seller, "is_buyer_plus", buyer_active)
    setattr(seller, "is_driver_pro", seller_active)
    setattr(seller, "show_plus_badge", buyer_active)
    setattr(seller, "promotional_ads_suppressed", buyer_active)
    return seller_active


def apply_seller_premium_expiry(seller: SellerProfile, *, persist: bool = False) -> bool:
    return attach_premium_flags(seller, persist=persist)
