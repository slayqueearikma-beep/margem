"""Stripe billing: Checkout, Customer Portal, plan changes, webhooks."""

from typing import Annotated

from fastapi import APIRouter, Body, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, require_seller
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import User
from app.schemas.billing import (
    BillingConfigOut,
    ChangePlanRequest,
    CheckoutCreate,
    CheckoutOut,
    PortalOut,
    SubscriptionOut,
    SyncSubscriptionRequest,
)
from app.services.stripe_billing import (
    cancel_subscription_at_period_end,
    change_subscription_plan,
    create_checkout_session,
    create_customer_portal_session,
    handle_stripe_webhook,
    require_stripe_configured,
    sync_user_subscription_from_stripe,
)
from app.services.subscription_activation import get_subscription_out

router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("/config", response_model=BillingConfigOut)
async def billing_config() -> BillingConfigOut:
    return BillingConfigOut(
        stripe_enabled=settings.stripe_enabled,
        publishable_key=settings.stripe_publishable_key,
        self_serve_enabled=settings.stripe_enabled,
        trial_enabled=settings.stripe_trial_enabled,
    )


@router.post("/checkout", response_model=CheckoutOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("20/minute")
async def start_checkout(
    request: Request,
    payload: Annotated[CheckoutCreate, Body()],
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> CheckoutOut:
    """Create a Stripe Checkout session for a business subscription plan."""
    require_stripe_configured()
    url, session_id = await create_checkout_session(
        session,
        user=user,
        plan_code=payload.plan_code,
        interval=payload.interval,
    )
    await session.commit()
    return CheckoutOut(checkout_url=url, session_id=session_id)


@router.post("/portal", response_model=PortalOut)
@limiter.limit("20/minute")
async def customer_portal(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PortalOut:
    """Open Stripe Customer Portal (manage payment method, invoices, cancel)."""
    require_stripe_configured()
    url = await create_customer_portal_session(user)
    return PortalOut(portal_url=url)


@router.post("/change-plan", response_model=SubscriptionOut)
@limiter.limit("10/minute")
async def change_plan(
    request: Request,
    payload: Annotated[ChangePlanRequest, Body()],
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Upgrade or downgrade the active Stripe subscription (prorated)."""
    subscription = await change_subscription_plan(
        session,
        user=user,
        plan_code=payload.plan_code,
        interval=payload.interval,
    )
    await session.commit()
    return SubscriptionOut.from_subscription(subscription)


@router.post("/sync", response_model=SubscriptionOut)
@limiter.limit("30/minute")
async def sync_subscription(
    request: Request,
    payload: Annotated[SyncSubscriptionRequest, Body()],
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Refresh subscription state from Stripe (e.g. immediately after Checkout)."""
    require_stripe_configured()
    subscription = await sync_user_subscription_from_stripe(
        session,
        user,
        checkout_session_id=payload.checkout_session_id,
    )
    if subscription is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No Stripe subscription found to sync",
        )
    await session.commit()
    return SubscriptionOut.from_subscription(subscription)


@router.post("/cancel", response_model=SubscriptionOut)
@limiter.limit("10/minute")
async def cancel_at_period_end(
    request: Request,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Schedule cancellation at the end of the current billing period."""
    subscription = await cancel_subscription_at_period_end(session, user)
    await session.commit()
    return SubscriptionOut.from_subscription(subscription)


@router.post("/webhooks/stripe", status_code=status.HTTP_200_OK)
@limiter.exempt
async def stripe_webhook(
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Stripe webhook endpoint — signature verified, idempotent."""
    payload = await request.body()
    signature = request.headers.get("stripe-signature")
    return await handle_stripe_webhook(session, payload, signature)
