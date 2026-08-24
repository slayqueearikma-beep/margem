"""Platform billing orchestration — subscriptions and advertising paid TO Dribex."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models import (
    AdvertisingCampaign,
    AdvertisingCampaignStatus,
    AdvertisingPackage,
    DribexServicePayment,
    PaymentWebhookEvent,
    PlatformPaymentStatus,
    Product,
    SellerProfile,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
)
from app.services.notifications import notify_user
from app.services.payment_provider import CheckoutSession, get_payment_provider, hash_webhook_payload
from app.services.subscription_service import ensure_checkout_allowed

logger = logging.getLogger("margem.billing")


async def create_subscription_checkout(
    session: AsyncSession,
    *,
    user: User,
    plan_code: str,
    success_url: str,
    cancel_url: str,
) -> tuple[DribexServicePayment, CheckoutSession]:
    plan = (
        await session.execute(
            select(SubscriptionPlan).where(
                SubscriptionPlan.code == plan_code,
                SubscriptionPlan.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if plan is None:
        raise ValueError("Plan not found")

    await ensure_checkout_allowed(session, user, plan)

    payment = DribexServicePayment(
        id=uuid4(),
        user_id=user.id,
        seller_id=None,
        service_type="subscription",
        service_code=plan.code,
        amount_mad=float(plan.price_mad),
        currency=settings.payment_currency,
        status=PlatformPaymentStatus.PENDING,
        provider=settings.payment_provider,
        metadata_={"plan_name": plan.name},
    )
    session.add(payment)
    await session.flush()

    provider = get_payment_provider()
    checkout = await provider.create_subscription_checkout(
        payment_id=payment.id,
        user_id=user.id,
        plan_code=plan.code,
        amount_mad=float(plan.price_mad),
        currency=settings.payment_currency,
        success_url=success_url,
        cancel_url=cancel_url,
    )
    payment.provider = checkout.provider
    payment.provider_reference = checkout.provider_reference
    if checkout.status == "success":
        payment.status = PlatformPaymentStatus.SUCCESS
        payment.paid_at = datetime.now(UTC)
        await activate_subscription_for_payment(session, payment=payment, user=user, plan=plan)
    await session.commit()
    await session.refresh(payment)
    return payment, checkout


async def create_advertising_checkout(
    session: AsyncSession,
    *,
    user: User,
    seller: SellerProfile,
    package_code: str,
    product_id: UUID | None,
    success_url: str,
    cancel_url: str,
) -> tuple[DribexServicePayment, AdvertisingCampaign, CheckoutSession]:
    package = (
        await session.execute(
            select(AdvertisingPackage).where(
                AdvertisingPackage.code == package_code,
                AdvertisingPackage.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if package is None:
        raise ValueError("Advertising package not found")

    if package.placement_type == "promoted_product":
        if product_id is None:
            raise ValueError("product_id is required for promoted product campaigns")
        product = (
            await session.execute(
                select(Product).where(Product.id == product_id, Product.seller_id == seller.id)
            )
        ).scalar_one_or_none()
        if product is None:
            raise ValueError("Product not found for this seller")

    payment = DribexServicePayment(
        id=uuid4(),
        user_id=user.id,
        seller_id=seller.id,
        service_type="advertising",
        service_code=package.code,
        amount_mad=float(package.price_mad),
        currency=settings.payment_currency,
        status=PlatformPaymentStatus.PENDING,
        provider=settings.payment_provider,
        metadata_={
            "package_name": package.name,
            "placement_type": package.placement_type,
            "product_id": str(product_id) if product_id else None,
        },
    )
    campaign = AdvertisingCampaign(
        id=uuid4(),
        seller_id=seller.id,
        product_id=product_id,
        package_id=package.id,
        payment_id=payment.id,
        status=AdvertisingCampaignStatus.PENDING,
    )
    session.add(payment)
    session.add(campaign)
    await session.flush()

    provider = get_payment_provider()
    checkout = await provider.create_advertising_checkout(
        payment_id=payment.id,
        user_id=user.id,
        package_code=package.code,
        amount_mad=float(package.price_mad),
        currency=settings.payment_currency,
        success_url=success_url,
        cancel_url=cancel_url,
        metadata={"seller_id": str(seller.id), "product_id": str(product_id) if product_id else ""},
    )
    payment.provider = checkout.provider
    payment.provider_reference = checkout.provider_reference
    if checkout.status == "success":
        payment.status = PlatformPaymentStatus.SUCCESS
        payment.paid_at = datetime.now(UTC)
        await activate_advertising_campaign(session, campaign=campaign, package=package, payment=payment)
    await session.commit()
    await session.refresh(payment)
    await session.refresh(campaign)
    return payment, campaign, checkout


async def activate_subscription_for_payment(
    session: AsyncSession,
    *,
    payment: DribexServicePayment,
    user: User,
    plan: SubscriptionPlan,
) -> Subscription:
    existing = await session.execute(
        select(Subscription).where(Subscription.user_id == user.id, Subscription.status == SubscriptionStatus.ACTIVE)
    )
    for sub in existing.scalars().all():
        sub.status = SubscriptionStatus.CANCELED

    now = datetime.now(UTC)
    subscription = Subscription(
        id=uuid4(),
        user_id=user.id,
        plan_id=plan.id,
        status=SubscriptionStatus.ACTIVE,
        current_period_start=now,
        current_period_end=now + timedelta(days=plan.billing_period_days),
        provider=payment.provider,
        provider_reference=payment.provider_reference,
    )
    session.add(subscription)
    user.is_premium = True
    user.premium_until = subscription.current_period_end

    if user.account_type.value == "seller" or plan.code.startswith("seller"):
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
        ).scalar_one_or_none()
        if seller:
            seller.is_premium = True

    await notify_user(
        session,
        user_id=user.id,
        title="Premium activated",
        body=f"{plan.name} is now active — platform service fee paid to Dribex",
        kind="premium",
        data={"plan_code": plan.code, "payment_id": str(payment.id)},
    )
    logger.info("subscription_activated user_id=%s plan=%s payment_id=%s", user.id, plan.code, payment.id)
    return subscription


async def activate_advertising_campaign(
    session: AsyncSession,
    *,
    campaign: AdvertisingCampaign,
    package: AdvertisingPackage,
    payment: DribexServicePayment,
) -> None:
    now = datetime.now(UTC)
    campaign.status = AdvertisingCampaignStatus.ACTIVE
    campaign.starts_at = now
    campaign.ends_at = now + timedelta(days=package.duration_days)

    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.id == campaign.seller_id))
    ).scalar_one_or_none()
    if seller is None:
        return

    if package.placement_type == "featured_seller":
        seller.is_premium = True
    elif package.placement_type == "promoted_product" and campaign.product_id:
        product = (
            await session.execute(select(Product).where(Product.id == campaign.product_id))
        ).scalar_one_or_none()
        if product:
            product.is_featured = True
    elif package.placement_type == "sponsored_listing":
        seller.is_premium = True

    await notify_user(
        session,
        user_id=payment.user_id,
        title="Advertising campaign active",
        body=f"{package.name} is now live on Dribex",
        kind="advertising",
        data={"campaign_id": str(campaign.id), "payment_id": str(payment.id)},
    )
    logger.info(
        "advertising_campaign_activated campaign_id=%s seller_id=%s payment_id=%s",
        campaign.id,
        campaign.seller_id,
        payment.id,
    )


async def mark_payment_failed(session: AsyncSession, payment: DribexServicePayment, *, reason: str) -> None:
    payment.status = PlatformPaymentStatus.FAILED
    payment.metadata_ = {**(payment.metadata_ or {}), "failure_reason": reason}
    logger.warning("platform_payment_failed payment_id=%s reason=%s", payment.id, reason)


async def process_provider_webhook(
    session: AsyncSession,
    *,
    provider_name: str,
    payload: bytes,
    signature_header: str | None,
) -> bool:
    provider = get_payment_provider()
    if provider.name != provider_name:
        raise ValueError("Webhook provider mismatch")

    verified = provider.verify_webhook(payload=payload, signature_header=signature_header)
    payload_hash = hash_webhook_payload(payload)
    existing = await session.execute(
        select(PaymentWebhookEvent).where(
            PaymentWebhookEvent.provider == provider_name,
            PaymentWebhookEvent.event_id == verified.event_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        logger.info("payment_webhook_duplicate provider=%s event_id=%s", provider_name, verified.event_id)
        return True

    session.add(
        PaymentWebhookEvent(
            id=uuid4(),
            provider=provider_name,
            event_id=verified.event_id,
            payload_hash=payload_hash,
        )
    )
    try:
        await session.flush()
    except IntegrityError:
        await session.rollback()
        logger.info(
            "payment_webhook_duplicate_race provider=%s event_id=%s",
            provider_name,
            verified.event_id,
        )
        return True

    if verified.event_type not in settings.naps_webhook_success_statuses:
        await session.commit()
        return True

    payment_id_raw = verified.metadata.get("dribex_payment_id")
    if not payment_id_raw:
        await session.commit()
        return True

    payment = (
        await session.execute(
            select(DribexServicePayment)
            .where(DribexServicePayment.id == UUID(payment_id_raw))
            .with_for_update()
        )
    ).scalar_one_or_none()
    if payment is None:
        await session.commit()
        return False

    if payment.status == PlatformPaymentStatus.SUCCESS:
        await session.commit()
        logger.info(
            "payment_webhook_already_processed payment_id=%s event_id=%s",
            payment.id,
            verified.event_id,
        )
        return True

    if verified.amount_mad is not None and abs(float(payment.amount_mad) - float(verified.amount_mad)) > 0.01:
        await mark_payment_failed(session, payment, reason="amount_mismatch")
        await session.commit()
        return False

    payment.status = PlatformPaymentStatus.SUCCESS
    payment.provider_reference = verified.provider_reference or payment.provider_reference
    payment.paid_at = datetime.now(UTC)

    user = (await session.execute(select(User).where(User.id == payment.user_id))).scalar_one_or_none()
    if user is None:
        await session.commit()
        return False

    if payment.service_type == "subscription":
        plan = (
            await session.execute(
                select(SubscriptionPlan).where(SubscriptionPlan.code == payment.service_code)
            )
        ).scalar_one_or_none()
        if plan:
            await activate_subscription_for_payment(session, payment=payment, user=user, plan=plan)
    elif payment.service_type == "advertising":
        campaign = (
            await session.execute(
                select(AdvertisingCampaign)
                .options(selectinload(AdvertisingCampaign.package))
                .where(AdvertisingCampaign.payment_id == payment.id)
            )
        ).scalar_one_or_none()
        if campaign and campaign.package:
            await activate_advertising_campaign(
                session, campaign=campaign, package=campaign.package, payment=payment
            )

    await session.commit()
    logger.info("payment_webhook_processed payment_id=%s event_id=%s", payment.id, verified.event_id)
    return True
