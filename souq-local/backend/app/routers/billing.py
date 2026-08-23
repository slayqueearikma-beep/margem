"""Billing endpoints — Dribex service payments only (subscriptions, advertising)."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, require_admin, require_seller, require_staff
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import (
    AdminAuditLog,
    AdvertisingCampaign,
    AdvertisingPackage,
    DribexServicePayment,
    PlatformPaymentStatus,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
)
from app.services.billing_service import billing_self_serve_enabled
from app.services.audit import log_security_event
from app.services.platform_billing import (
    create_advertising_checkout,
    create_subscription_checkout,
    process_provider_webhook,
)

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
    provider_reference: str
    created_at: str
    paid_at: str | None = None


class AdminPaymentOut(PlatformPaymentOut):
    user_id: UUID
    user_email: str


class AdminSubscriptionOut(BaseModel):
    id: UUID
    user_id: UUID
    user_email: str
    plan_code: str
    plan_name: str
    status: str
    provider: str
    provider_reference: str
    current_period_start: str
    current_period_end: str
    cancelled_at: str | None = None


class AdminCampaignOut(BaseModel):
    id: UUID
    seller_id: UUID
    package_code: str
    status: str
    amount_mad: float | None
    payment_status: str | None
    starts_at: str | None
    ends_at: str | None


def _default_success_url(custom: str) -> str:
    from app.services.media_access import validate_checkout_redirect_url

    return validate_checkout_redirect_url(custom, default_suffix="/premium?paid=1")


def _default_cancel_url(custom: str) -> str:
    from app.services.media_access import validate_checkout_redirect_url

    return validate_checkout_redirect_url(custom, default_suffix="/premium?cancelled=1")


def _payment_out(row: DribexServicePayment) -> PlatformPaymentOut:
    return PlatformPaymentOut(
        id=row.id,
        service_type=row.service_type,
        service_code=row.service_code,
        amount_mad=float(row.amount_mad),
        currency=row.currency,
        status=row.status.value,
        provider=row.provider,
        provider_reference=row.provider_reference,
        created_at=row.created_at.isoformat(),
        paid_at=row.paid_at.isoformat() if row.paid_at else None,
    )


def _ensure_self_serve_available() -> None:
    if settings.app_env in {"production", "prod", "staging"} and settings.payment_provider != "naps":
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Self-serve billing requires NAPS. "
                "Dribex does not process buyer-to-seller product payments."
            ),
        )
    if not billing_self_serve_enabled():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Billing is not available in this environment.",
        )


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
    _ensure_self_serve_available()
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

    _ensure_self_serve_available()
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
    return [_payment_out(row) for row in rows]


@router.get("/payments/{payment_id}", response_model=PlatformPaymentOut)
async def get_payment_status(
    payment_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PlatformPaymentOut:
    payment = await session.get(DribexServicePayment, payment_id)
    if payment is None or payment.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return _payment_out(payment)


@router.post("/subscriptions/me/cancel", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_my_subscription(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    """Cancel premium at period end. Access continues until current_period_end."""
    sub = (
        await session.execute(
            select(Subscription)
            .where(
                Subscription.user_id == user.id,
                Subscription.status == SubscriptionStatus.ACTIVE,
            )
            .order_by(Subscription.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if sub is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active subscription")
    if sub.cancelled_at is not None:
        return  # idempotent — already scheduled for cancellation
    sub.cancelled_at = datetime.now(UTC)
    await session.commit()
    log_security_event("subscription_cancelled", user_id=str(user.id), subscription_id=str(sub.id))


@router.post("/webhooks/{provider_name}", status_code=status.HTTP_204_NO_CONTENT)
@limiter.exempt
async def payment_webhook(
    provider_name: str,
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> None:
    payload = await request.body()
    signature = request.headers.get(settings.naps_webhook_signature_header)
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


@router.get("/admin/payments", response_model=list[AdminPaymentOut])
async def admin_list_payments(
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[AdminPaymentOut]:
    rows = (
        await session.execute(
            select(DribexServicePayment, User.email)
            .join(User, User.id == DribexServicePayment.user_id)
            .order_by(DribexServicePayment.created_at.desc())
            .limit(limit)
        )
    ).all()
    return [
        AdminPaymentOut(
            **_payment_out(payment).model_dump(),
            user_id=payment.user_id,
            user_email=email,
        )
        for payment, email in rows
    ]


@router.get("/admin/subscriptions", response_model=list[AdminSubscriptionOut])
async def admin_list_subscriptions(
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[AdminSubscriptionOut]:
    rows = (
        await session.execute(
            select(Subscription, User.email, SubscriptionPlan)
            .join(User, User.id == Subscription.user_id)
            .join(SubscriptionPlan, SubscriptionPlan.id == Subscription.plan_id)
            .order_by(Subscription.created_at.desc())
            .limit(limit)
        )
    ).all()
    return [
        AdminSubscriptionOut(
            id=sub.id,
            user_id=sub.user_id,
            user_email=email,
            plan_code=plan.code,
            plan_name=plan.name,
            status=sub.status.value,
            provider=sub.provider,
            provider_reference=sub.provider_reference,
            current_period_start=sub.current_period_start.isoformat(),
            current_period_end=sub.current_period_end.isoformat(),
            cancelled_at=sub.cancelled_at.isoformat() if sub.cancelled_at else None,
        )
        for sub, email, plan in rows
    ]


@router.get("/admin/campaigns", response_model=list[AdminCampaignOut])
async def admin_list_campaigns(
    admin: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
) -> list[AdminCampaignOut]:
    rows = (
        await session.execute(
            select(AdvertisingCampaign)
            .options(
                selectinload(AdvertisingCampaign.package),
                selectinload(AdvertisingCampaign.payment),
            )
            .order_by(AdvertisingCampaign.created_at.desc())
            .limit(limit)
        )
    ).scalars().all()
    results: list[AdminCampaignOut] = []
    for campaign in rows:
        payment = campaign.payment
        results.append(
            AdminCampaignOut(
                id=campaign.id,
                seller_id=campaign.seller_id,
                package_code=campaign.package.code if campaign.package else "",
                status=campaign.status.value,
                amount_mad=float(payment.amount_mad) if payment else None,
                payment_status=payment.status.value if payment else None,
                starts_at=campaign.starts_at.isoformat() if campaign.starts_at else None,
                ends_at=campaign.ends_at.isoformat() if campaign.ends_at else None,
            )
        )
    return results


@router.post("/admin/payments/{payment_id}/reconcile", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("20/minute")
async def admin_reconcile_payment(
    request: Request,
    payment_id: UUID,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    """Mark payment for manual reconciliation review — does not alter payment status."""
    payment = await session.get(DribexServicePayment, payment_id)
    if payment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    payment.metadata_ = {
        **(payment.metadata_ or {}),
        "reconciliation_flagged_at": datetime.now(UTC).isoformat(),
        "reconciliation_flagged_by": str(admin.id),
    }
    session.add(
        AdminAuditLog(
            id=uuid4(),
            actor_id=admin.id,
            action="flag_payment_reconciliation",
            target_type="payment",
            target_id=str(payment_id),
            metadata_={"provider": payment.provider, "status": payment.status.value},
        )
    )
    await session.commit()
