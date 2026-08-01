"""Immutable administrator audit trail."""

from __future__ import annotations

from uuid import UUID, uuid4

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AdminAuditLog
from app.services.client_ip import get_client_ip


def _client_meta(request: Request | None) -> tuple[str, str]:
    if request is None:
        return "", ""
    ip = get_client_ip(request)
    ua = request.headers.get("user-agent", "")[:255]
    return ip, ua


async def record_admin_action(
    session: AsyncSession,
    *,
    actor_id: UUID,
    action: str,
    target_type: str = "",
    target_id: str = "",
    metadata: dict | None = None,
    previous_value: dict | None = None,
    new_value: dict | None = None,
    success: bool = True,
    request: Request | None = None,
) -> AdminAuditLog:
    """Append an immutable audit log entry. Never update or delete audit rows."""
    ip, ua = _client_meta(request)
    entry = AdminAuditLog(
        id=uuid4(),
        actor_id=actor_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        metadata_=metadata or {},
        ip_address=ip,
        user_agent=ua,
        success=success,
        previous_value=previous_value,
        new_value=new_value,
    )
    session.add(entry)
    return entry
