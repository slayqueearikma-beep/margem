"""Stripe Checkout, Customer Portal, webhooks, and subscription reconciliation."""

from __future__ import annotations

import logging
from uuid import uuid4

import stripe
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    SellerProfile,
    StripeWebhookEvent,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
)
from app.services.subscription_plans import (
    get_plan_by_code_optional,
    plan_allows_stripe_checkout,
)
from app.services.subscription_activation import (
    ACTIVE_PREMIUM_STATUSES,
    deactivate_user_subscription,
    stripe_status_to_subscription_status,
    subscription_grants_premium,
    upsert_subscription_record,
    utc_from_timestamp,
)

logger = logging.getLogger("margem.stripe")


def _configure_stripe() -> None:
    if settings.stripe_secret_key:
        stripe.api_key = settings.stripe_secret_key


def require_stripe_configured() -> None:
    if not settings.stripe_enabled:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Stripe billing is not configured on this server",
        )


async def require_business_user(session: AsyncSession, user: User) -> SellerProfile:
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()
    if seller is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only registered businesses can purchase subscription plans",
        )
    return seller


async def get_plan_by_code(session: AsyncSession, plan_code: str) -> SubscriptionPlan:
    plan = await get_plan_by_code_optional(session, plan_code)
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plan not found")
    return plan


def resolve_stripe_price_id(plan: SubscriptionPlan, interval: str) -> str:
    price_id = plan.stripe_price_id_monthly if interval == "monthly" else plan.stripe_price_id_yearly
    if not price_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Stripe price not configured for {plan.code} ({interval})",
        )
    return price_id


async def get_or_create_stripe_customer(session: AsyncSession, user: User) -> str:
    locked = (
        await session.execute(select(User).where(User.id == user.id).with_for_update())
    ).scalar_one()
    if locked.stripe_customer_id:
        user.stripe_customer_id = locked.stripe_customer_id
        return locked.stripe_customer_id

    _configure_stripe()
    customer = stripe.Customer.create(
        email=locked.email,
        name=locked.display_name or locked.email,
        metadata={"user_id": str(locked.id)},
    )
    locked.stripe_customer_id = customer["id"]
    user.stripe_customer_id = customer["id"]
    await session.flush()
    return customer["id"]


async def create_checkout_session(
    session: AsyncSession,
    *,
    user: User,
    plan_code: str,
    interval: str,
) -> tuple[str, str]:
    require_stripe_configured()
    await require_business_user(session, user)
    plan = await get_plan_by_code(session, plan_code)
    if not plan_allows_stripe_checkout(plan):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This plan does not require checkout — it is included for free",
        )
    price_id = resolve_stripe_price_id(plan, interval)
    customer_id = await get_or_create_stripe_customer(session, user)

    _configure_stripe()
    existing = (
        await session.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.status.in_(list(ACTIVE_PREMIUM_STATUSES)),
                Subscription.stripe_subscription_id.is_not(None),
            )
        )
    ).scalar_one_or_none()

    subscription_data: dict = {
        "metadata": {
            "user_id": str(user.id),
            "plan_code": plan.code,
            "interval": interval,
        },
    }
    if settings.stripe_trial_enabled and plan.trial_days > 0 and existing is None:
        subscription_data["trial_period_days"] = plan.trial_days

    checkout_session = stripe.checkout.Session.create(
        mode="subscription",
        customer=customer_id,
        line_items=[{"price": price_id, "quantity": 1}],
        success_url=f"{settings.stripe_checkout_success_url}?session_id={{CHECKOUT_SESSION_ID}}",
        cancel_url=settings.stripe_checkout_cancel_url,
        client_reference_id=str(user.id),
        metadata={
            "user_id": str(user.id),
            "plan_code": plan.code,
            "interval": interval,
        },
        subscription_data=subscription_data,
        allow_promotion_codes=True,
        billing_address_collection="auto",
        customer_update={"address": "auto"},
    )
    return checkout_session["url"], checkout_session["id"]


async def create_customer_portal_session(user: User) -> str:
    require_stripe_configured()
    if not user.stripe_customer_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No Stripe customer record — subscribe first",
        )
    _configure_stripe()
    portal = stripe.billing_portal.Session.create(
        customer=user.stripe_customer_id,
        return_url=settings.stripe_customer_portal_return_url,
    )
    return portal["url"]


async def change_subscription_plan(
    session: AsyncSession,
    *,
    user: User,
    plan_code: str,
    interval: str,
) -> Subscription:
    require_stripe_configured()
    plan = await get_plan_by_code(session, plan_code)
    if not plan_allows_stripe_checkout(plan):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This plan does not require checkout — it is included for free",
        )
    price_id = resolve_stripe_price_id(plan, interval)
    active = (
        await session.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.status.in_(list(ACTIVE_PREMIUM_STATUSES)),
                Subscription.stripe_subscription_id.is_not(None),
            )
        )
    ).scalar_one_or_none()
    if active is None:
        raise HTTPException(status_code=400, detail="No active Stripe subscription")

    _configure_stripe()
    stripe_sub = stripe.Subscription.retrieve(active.stripe_subscription_id)
    item_id = stripe_sub["items"]["data"][0]["id"]
    updated = stripe.Subscription.modify(
        active.stripe_subscription_id,
        items=[{"id": item_id, "price": price_id}],
        metadata={
            "user_id": str(user.id),
            "plan_code": plan.code,
            "interval": interval,
        },
        proration_behavior="create_prorations",
    )
    return await sync_subscription_from_stripe_object(
        session,
        user=user,
        stripe_sub=updated,
        plan=plan,
    )


async def cancel_subscription_at_period_end(session: AsyncSession, user: User) -> Subscription:
    require_stripe_configured()
    active = (
        await session.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.status.in_(list(ACTIVE_PREMIUM_STATUSES)),
                Subscription.stripe_subscription_id.is_not(None),
            )
        )
    ).scalar_one_or_none()
    if active is None:
        raise HTTPException(status_code=400, detail="No active Stripe subscription")

    _configure_stripe()
    updated = stripe.Subscription.modify(
        active.stripe_subscription_id,
        cancel_at_period_end=True,
    )
    plan = await session.get(SubscriptionPlan, active.plan_id)
    assert plan is not None
    return await sync_subscription_from_stripe_object(session, user=user, stripe_sub=updated, plan=plan)


async def _resolve_plan_from_stripe_sub(
    session: AsyncSession,
    stripe_sub: dict,
    plan: SubscriptionPlan | None = None,
) -> SubscriptionPlan | None:
    if plan is not None:
        return plan
    plan_code = (stripe_sub.get("metadata") or {}).get("plan_code")
    if plan_code:
        plan = await get_plan_by_code_optional(session, plan_code)
    if plan is not None:
        return plan

    items = stripe_sub.get("items", {}).get("data") or []
    if not items:
        return None
    price = items[0].get("price") or {}
    price_id = price.get("id")
    if not price_id:
        return None
    return (
        await session.execute(
            select(SubscriptionPlan).where(
                (SubscriptionPlan.stripe_price_id_monthly == price_id)
                | (SubscriptionPlan.stripe_price_id_yearly == price_id)
            )
        )
    ).scalar_one_or_none()


async def sync_subscription_from_stripe_object(
    session: AsyncSession,
    *,
    user: User,
    stripe_sub: dict,
    plan: SubscriptionPlan | None = None,
    notify: bool = True,
    strict: bool = True,
) -> Subscription | None:
    plan = await _resolve_plan_from_stripe_sub(session, stripe_sub, plan)
    if plan is None:
        message = "Unable to resolve subscription plan from Stripe data"
        if strict:
            raise HTTPException(status_code=500, detail=message)
        logger.error(
            "stripe_plan_resolution_failed sub=%s user=%s",
            stripe_sub.get("id"),
            user.id,
        )
        return None

    items = stripe_sub.get("items", {}).get("data") or []
    interval = (stripe_sub.get("metadata") or {}).get("interval")
    if not interval and items:
        recurring = items[0].get("price", {}).get("recurring") or {}
        interval = recurring.get("interval", "month")
        if interval == "year":
            interval = "yearly"
        elif interval == "month":
            interval = "monthly"
    interval = interval or "monthly"

    sub_status = stripe_status_to_subscription_status(stripe_sub.get("status", "canceled"))
    subscription = await upsert_subscription_record(
        session,
        user=user,
        plan=plan,
        status=sub_status,
        period_start=utc_from_timestamp(stripe_sub.get("current_period_start")),
        period_end=utc_from_timestamp(stripe_sub.get("current_period_end")),
        provider="stripe",
        provider_reference=stripe_sub["id"],
        stripe_subscription_id=stripe_sub["id"],
        billing_interval=interval,
        cancel_at_period_end=bool(stripe_sub.get("cancel_at_period_end")),
        notify=notify and subscription_grants_premium(sub_status),
    )

    return subscription


async def record_webhook_event(session: AsyncSession, event_id: str, event_type: str) -> bool:
    """Return True if this event should be processed (not a duplicate)."""
    existing = (
        await session.execute(select(StripeWebhookEvent).where(StripeWebhookEvent.event_id == event_id))
    ).scalar_one_or_none()
    if existing is not None:
        return False
    session.add(
        StripeWebhookEvent(
            id=uuid4(),
            event_id=event_id,
            event_type=event_type,
        )
    )
    try:
        await session.flush()
    except IntegrityError:
        await session.rollback()
        return False
    return True


async def handle_stripe_webhook(session: AsyncSession, payload: bytes, signature: str | None) -> dict:
    require_stripe_configured()
    if not settings.stripe_webhook_secret:
        raise HTTPException(status_code=503, detail="Stripe webhook secret not configured")
    if not signature:
        raise HTTPException(status_code=400, detail="Missing Stripe-Signature header")

    _configure_stripe()
    try:
        event = stripe.Webhook.construct_event(payload, signature, settings.stripe_webhook_secret)
    except stripe.error.SignatureVerificationError as exc:
        logger.warning("stripe_webhook_signature_failed")
        raise HTTPException(status_code=400, detail="Invalid webhook signature") from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Invalid webhook payload") from exc

    if not await record_webhook_event(session, event["id"], event["type"]):
        return {"status": "duplicate", "event_id": event["id"]}

    event_type = event["type"]
    data_object = event["data"]["object"]

    if event_type == "checkout.session.completed":
        await _handle_checkout_completed(session, data_object)
    elif event_type in {"customer.subscription.created", "customer.subscription.updated"}:
        await _handle_subscription_upsert(session, data_object)
    elif event_type == "customer.subscription.deleted":
        await _handle_subscription_deleted(session, data_object)
    elif event_type == "invoice.paid":
        await _handle_invoice_paid(session, data_object)
    elif event_type == "invoice.payment_failed":
        await _handle_invoice_payment_failed(session, data_object)
    else:
        logger.info("stripe_webhook_ignored type=%s", event_type)

    await session.commit()
    return {"status": "ok", "event_id": event["id"], "type": event_type}


async def _resolve_user(session: AsyncSession, user_id: str | None, customer_id: str | None) -> User | None:
    if user_id:
        user = await session.get(User, user_id)
        if user is not None:
            return user
    if customer_id:
        result = await session.execute(select(User).where(User.stripe_customer_id == customer_id))
        return result.scalar_one_or_none()
    return None


async def _handle_checkout_completed(session: AsyncSession, checkout_session: dict) -> None:
    user_id = checkout_session.get("client_reference_id") or (checkout_session.get("metadata") or {}).get("user_id")
    customer_id = checkout_session.get("customer")
    user = await _resolve_user(session, user_id, customer_id)
    if user is None:
        logger.error("checkout_completed_user_not_found session=%s", checkout_session.get("id"))
        return

    subscription_id = checkout_session.get("subscription")
    if not subscription_id:
        return

    _configure_stripe()
    stripe_sub = stripe.Subscription.retrieve(subscription_id)
    plan_code = (checkout_session.get("metadata") or {}).get("plan_code")
    plan = await get_plan_by_code_optional(session, plan_code) if plan_code else None
    await sync_subscription_from_stripe_object(
        session,
        user=user,
        stripe_sub=stripe_sub,
        plan=plan,
        strict=False,
    )


async def _handle_subscription_upsert(session: AsyncSession, stripe_sub: dict) -> None:
    user_id = (stripe_sub.get("metadata") or {}).get("user_id")
    customer_id = stripe_sub.get("customer")
    user = await _resolve_user(session, user_id, customer_id)
    if user is None:
        logger.error("subscription_upsert_user_not_found sub=%s", stripe_sub.get("id"))
        return
    await sync_subscription_from_stripe_object(session, user=user, stripe_sub=stripe_sub, strict=False)


async def _handle_subscription_deleted(session: AsyncSession, stripe_sub: dict) -> None:
    user_id = (stripe_sub.get("metadata") or {}).get("user_id")
    customer_id = stripe_sub.get("customer")
    user = await _resolve_user(session, user_id, customer_id)
    if user is None:
        return
    existing = (
        await session.execute(
            select(Subscription).where(Subscription.stripe_subscription_id == stripe_sub["id"])
        )
    ).scalar_one_or_none()
    if existing:
        existing.status = SubscriptionStatus.CANCELED
        existing.cancel_at_period_end = False
    await deactivate_user_subscription(session, user, reason="canceled")


async def _handle_invoice_paid(session: AsyncSession, invoice: dict) -> None:
    subscription_id = invoice.get("subscription")
    if not subscription_id:
        return
    _configure_stripe()
    stripe_sub = stripe.Subscription.retrieve(subscription_id)
    await _handle_subscription_upsert(session, stripe_sub)


async def _handle_invoice_payment_failed(session: AsyncSession, invoice: dict) -> None:
    subscription_id = invoice.get("subscription")
    if not subscription_id:
        return
    result = await session.execute(
        select(Subscription).where(Subscription.stripe_subscription_id == subscription_id)
    )
    subscription = result.scalar_one_or_none()
    if subscription is None:
        return
    subscription.status = SubscriptionStatus.PAST_DUE
    user = await session.get(User, subscription.user_id)
    if user is None:
        return
    from app.services.notifications import notify_user

    await notify_user(
        session,
        user_id=user.id,
        title="Payment failed",
        body="We could not process your subscription payment. Update your billing details to keep premium visibility.",
        kind="premium",
        data={"stripe_subscription_id": subscription_id},
    )


async def sync_user_subscription_from_stripe(
    session: AsyncSession,
    user: User,
    *,
    checkout_session_id: str | None = None,
) -> Subscription | None:
    """Pull the latest subscription state from Stripe for the current user."""
    require_stripe_configured()
    _configure_stripe()

    if checkout_session_id:
        checkout = stripe.checkout.Session.retrieve(checkout_session_id)
        owner_id = checkout.get("client_reference_id") or (checkout.get("metadata") or {}).get("user_id")
        if owner_id and str(owner_id) != str(user.id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Checkout session does not belong to this account",
            )
        subscription_id = checkout.get("subscription")
        if not subscription_id:
            return None
        stripe_sub = stripe.Subscription.retrieve(subscription_id)
        plan_code = (checkout.get("metadata") or {}).get("plan_code")
        plan = await get_plan_by_code_optional(session, plan_code) if plan_code else None
        return await sync_subscription_from_stripe_object(
            session,
            user=user,
            stripe_sub=stripe_sub,
            plan=plan,
        )

    active = (
        await session.execute(
            select(Subscription).where(
                Subscription.user_id == user.id,
                Subscription.stripe_subscription_id.is_not(None),
            )
            .order_by(Subscription.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if active is None or not active.stripe_subscription_id:
        return None

    stripe_sub = stripe.Subscription.retrieve(active.stripe_subscription_id)
    return await sync_subscription_from_stripe_object(session, user=user, stripe_sub=stripe_sub)


async def reconcile_stripe_subscriptions(session: AsyncSession) -> dict:
    """Sync local subscription rows with Stripe (repair drift)."""
    if not settings.stripe_enabled:
        return {"checked": 0, "updated": 0, "errors": 0}

    _configure_stripe()
    result = await session.execute(
        select(Subscription).where(Subscription.stripe_subscription_id.is_not(None))
    )
    subs = list(result.scalars().all())
    updated = 0
    errors = 0
    for local in subs:
        try:
            stripe_sub = stripe.Subscription.retrieve(local.stripe_subscription_id)
            user = await session.get(User, local.user_id)
            if user is None:
                continue
            synced = await sync_subscription_from_stripe_object(
                session,
                user=user,
                stripe_sub=stripe_sub,
                notify=False,
                strict=False,
            )
            if synced is not None:
                updated += 1
        except Exception:
            logger.exception("stripe_reconcile_failed sub=%s", local.stripe_subscription_id)
            errors += 1
    await session.commit()
    return {"checked": len(subs), "updated": updated, "errors": errors}

