"""Partnership audit logging."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.partnership import PartnershipAuditLog


async def log_partnership_action(
    session: AsyncSession,
    *,
    partnership_id: UUID,
    action: str,
    actor_user_id: UUID | None = None,
    actor_seller_id: UUID | None = None,
    target_type: str = "",
    target_id: str = "",
    metadata: dict | None = None,
) -> PartnershipAuditLog:
    entry = PartnershipAuditLog(
        partnership_id=partnership_id,
        actor_user_id=actor_user_id,
        actor_seller_id=actor_seller_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        metadata_=metadata or {},
    )
    session.add(entry)
    return entry
