"""Billing endpoints — Dribex service payments only (subscriptions, advertising)."""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, require_seller
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AdvertisingPackage, DribexServicePayment, User
from app.services.platform_billing import create_advertising_checkout, create_subscription_checkout, process_provider_webhook

router = APIRouter(prefix="/billing", tags=["billing"])


class CheckoutOut(BaseModel):
    payment_id: UUID
    status: str
    checkout_url: str | None = None
    provider: str


class AdvertisingCheckoutIn(BaseModel):
    package_code: str = Field(max_length=64)
    product_id: UUID | None = None
    success_url: str = Field(default="", max_length=2048)
    cancel_url: str = Field(default="", max_length=2048)


class SubscriptionCheckoutIn(BaseModel):
    success_url: str = Field(default="", max_length=2048)
    cancel_url: str = Field(default="", max_length=2048)


class AdvertisingPackageOut(BaseModel):
    code: str
    name: str
    description: str
    placement_type: str
    price_mad: float
    duration_days: int

    model_config = {"from_attributes": True}


class PlatformPaymentOut(BaseModel):
    id: UUID
    service_type: str
    service_code: str
    amount_mad: float
    currency: str
    status: str
    provider: str
    created_at: str


def _default_success_url(custom: str) -> str:
    return custom.strip() or f"{settings.public_app_url.rstrip('/')}/premium?paid=1"


def _default_cancel_url(custom: str) -> str:
    return custom.strip() or f"{settings.public_app_url.rstrip('/')}/premium?cancelled=1"


@router.get("/advertising/packages", response_model=list[AdvertisingPackageOut])
async def list_advertising_packages(session: AsyncSession = Depends(get_db)) -> list[AdvertisingPackage]:
    result = await session.execute(
        select(AdvertisingPackage).where(AdvertisingPackage.is_active.is_(True)).order_by(AdvertisingPackage.price_mad.asc())
    )
    return list(result.scalars().all())


@router.post("/checkout/subscription/{plan_code}", response_model=CheckoutOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def checkout_subscription(
    request: Request,
    plan_code: str,
    payload: SubscriptionCheckoutIn,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CheckoutOut:
    """Start checkout for a Dribex premium subscription (platform service fee)."""
    if settings.app_env in {"production", "prod"} and settings.payment_provider == "manual":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Self-serve billing requires a configured payment provider. "
                "Dribex does not process buyer-to-seller product payments."
            ),
        )
    try:
        payment, checkout = await create_subscription_checkout(
            session,
            user=user,
            plan_code=plan_code,
            success_url=_default_success_url(payload.success_url),
            cancel_url=_default_cancel_url(payload.cancel_url),
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return CheckoutOut(
        payment_id=payment.id,
        status=payment.status.value,
        checkout_url=checkout.checkout_url,
        provider=checkout.provider,
    )


@router.post("/checkout/advertising", response_model=CheckoutOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def checkout_advertising(
    request: Request,
    payload: AdvertisingCheckoutIn,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> CheckoutOut:
    """Start checkout for a Dribex advertising package (platform service fee)."""
    from app.routers.seller_ops import _seller_profile

    if settings.app_env in {"production", "prod"} and settings.payment_provider == "manual":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Self-serve advertising billing requires a configured payment provider.",
        )
    seller = await _seller_profile(user, session)
    try:
        payment, _campaign, checkout = await create_advertising_checkout(
            session,
            user=user,
            seller=seller,
            package_code=payload.package_code,
            product_id=payload.product_id,
            success_url=_default_success_url(payload.success_url),
            cancel_url=_default_cancel_url(payload.cancel_url),
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return CheckoutOut(
        payment_id=payment.id,
        status=payment.status.value,
        checkout_url=checkout.checkout_url,
        provider=checkout.provider,
    )


@router.get("/payments/me", response_model=list[PlatformPaymentOut])
async def my_platform_payments(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[PlatformPaymentOut]:
    rows = (
        await session.execute(
            select(DribexServicePayment)
            .where(DribexServicePayment.user_id == user.id)
            .order_by(DribexServicePayment.created_at.desc())
            .limit(50)
        )
    ).scalars().all()
    return [
        PlatformPaymentOut(
            id=row.id,
            service_type=row.service_type,
            service_code=row.service_code,
            amount_mad=float(row.amount_mad),
            currency=row.currency,
            status=row.status.value,
            provider=row.provider,
            created_at=row.created_at.isoformat(),
        )
        for row in rows
    ]


@router.post("/webhooks/{provider_name}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.exempt
async def payment_webhook(
    provider_name: str,
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> None:
    payload = await request.body()
    signature = request.headers.get("stripe-signature")
    try:
        ok = await process_provider_webhook(
            session,
            provider_name=provider_name,
            payload=payload,
            signature_header=signature,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    if not ok:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
