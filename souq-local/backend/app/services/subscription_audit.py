"""Subscription audit trail — no secrets or payment PAN data."""

from __future__ import annotations

import logging
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SubscriptionEvent

logger = logging.getLogger("margem.subscriptions")


async def record_subscription_event(
    session: AsyncSession,
    *,
    user_id: UUID,
    plan_code: str,
    event_type: str,
    subscription_id: UUID | None = None,
    metadata: dict | None = None,
) -> None:
    safe_metadata = metadata or {}
    session.add(
        SubscriptionEvent(
            id=uuid4(),
            user_id=user_id,
            subscription_id=subscription_id,
            plan_code=plan_code,
            event_type=event_type,
            metadata_=safe_metadata,
        )
    )
    logger.info(
        "subscription_event type=%s user_id=%s plan=%s subscription_id=%s",
        event_type,
        user_id,
        plan_code,
        subscription_id,
    )
