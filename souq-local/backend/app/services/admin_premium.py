"""Admin premium grant/revoke — shared by admin router (no seller_ops coupling)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import (
    SellerProfile,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
)
from app.schemas.billing import PlanOut, SubscriptionOut
from app.services.admin_audit import record_admin_action
from app.services.notifications import notify_user
from app.services.subscription_plans import is_free_plan


async def admin_grant_premium(
    session: AsyncSession,
    *,
    admin: User,
    user_id: UUID,
    plan_code: str,
    days: int,
    request: Request | None = None,
) -> SubscriptionOut:
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    plan = (
        await session.execute(
            select(SubscriptionPlan).where(
                SubscriptionPlan.code == plan_code,
                SubscriptionPlan.is_active.is_(True),
            )
        )
    ).scalar_one_or_none()
    if plan is None:
        raise HTTPException(status_code=404, detail="Plan not found")

    if is_free_plan(plan):
        from app.services.subscription_plans import assign_basic_plan

        subscription = await assign_basic_plan(session, target, provider="admin_grant", notify=True)
        await record_admin_action(
            session,
            actor_id=admin.id,
            action="grant_premium",
            target_type="user",
            target_id=str(user_id),
            new_value={"plan_code": plan.code, "days": 0},
            request=request,
        )
        await session.commit()
        result = await session.execute(
            select(Subscription).options(selectinload(Subscription.plan)).where(Subscription.id == subscription.id)
        )
        subscription = result.scalar_one()
        return SubscriptionOut.from_subscription(subscription)

    existing = await session.execute(
        select(Subscription).where(
            Subscription.user_id == target.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
    )
    for sub in existing.scalars().all():
        sub.status = SubscriptionStatus.CANCELED

    now = datetime.now(UTC)
    subscription = Subscription(
        id=uuid4(),
        user_id=target.id,
        plan_id=plan.id,
        status=SubscriptionStatus.ACTIVE,
        current_period_start=now,
        current_period_end=now + timedelta(days=days),
        provider="admin_grant",
        provider_reference=f"admin-{admin.id.hex[:8]}-{uuid4().hex[:8]}",
    )
    session.add(subscription)
    target.is_premium = True
    target.premium_until = subscription.current_period_end
    if target.account_type.value == "seller" or plan.code.startswith("seller"):
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == target.id))
        ).scalar_one_or_none()
        if seller:
            seller.is_premium = True

    await record_admin_action(
        session,
        actor_id=admin.id,
        action="grant_premium",
        target_type="user",
        target_id=str(user_id),
        new_value={"plan_code": plan.code, "days": days},
        request=request,
    )
    await notify_user(
        session,
        user_id=target.id,
        title="Premium activated",
        body=f"{plan.name} granted by MarGem staff",
        kind="premium",
        data={"plan_code": plan.code},
    )
    await session.commit()
    await session.refresh(subscription)
    result = await session.execute(
        select(Subscription).options(selectinload(Subscription.plan)).where(Subscription.id == subscription.id)
    )
    subscription = result.scalar_one()
    return SubscriptionOut.from_subscription(subscription)
