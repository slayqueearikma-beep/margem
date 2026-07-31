"""Billing API schemas."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models import Subscription, SubscriptionPlan, SubscriptionStatus


class PlanOut(BaseModel):
    id: UUID
    code: str
    name: str
    description: str
    price_mad: float
    price_mad_yearly: float | None = None
    billing_period_days: int
    tier_level: int = 1
    trial_days: int = 0
    features: list
    is_active: bool

    model_config = {"from_attributes": True}

    @classmethod
    def from_plan(cls, plan: SubscriptionPlan) -> "PlanOut":
        return cls(
            id=plan.id,
            code=plan.code,
            name=plan.name,
            description=plan.description,
            price_mad=float(plan.price_mad),
            price_mad_yearly=float(plan.price_mad_yearly) if plan.price_mad_yearly is not None else None,
            billing_period_days=plan.billing_period_days,
            tier_level=plan.tier_level,
            trial_days=plan.trial_days,
            features=list(plan.features or []),
            is_active=plan.is_active,
        )


class SubscriptionOut(BaseModel):
    id: UUID
    plan: PlanOut
    status: SubscriptionStatus
    current_period_start: datetime
    current_period_end: datetime
    provider: str
    provider_reference: str = ""
    stripe_subscription_id: str | None = None
    billing_interval: str = "monthly"
    cancel_at_period_end: bool = False

    @classmethod
    def from_subscription(cls, subscription: Subscription) -> "SubscriptionOut":
        return cls(
            id=subscription.id,
            plan=PlanOut.from_plan(subscription.plan),
            status=subscription.status,
            current_period_start=subscription.current_period_start,
            current_period_end=subscription.current_period_end,
            provider=subscription.provider,
            provider_reference=subscription.provider_reference or "",
            stripe_subscription_id=subscription.stripe_subscription_id,
            billing_interval=subscription.billing_interval,
            cancel_at_period_end=subscription.cancel_at_period_end,
        )


class BillingConfigOut(BaseModel):
    stripe_enabled: bool
    publishable_key: str = ""
    self_serve_enabled: bool
    trial_enabled: bool


class CheckoutCreate(BaseModel):
    plan_code: str = Field(min_length=2, max_length=40)
    interval: str = Field(default="monthly", pattern=r"^(monthly|yearly)$")


class CheckoutOut(BaseModel):
    checkout_url: str
    session_id: str


class PortalOut(BaseModel):
    portal_url: str


class ChangePlanRequest(BaseModel):
    plan_code: str = Field(min_length=2, max_length=40)
    interval: str = Field(default="monthly", pattern=r"^(monthly|yearly)$")


class SyncSubscriptionRequest(BaseModel):
    checkout_session_id: str | None = Field(default=None, max_length=120)
