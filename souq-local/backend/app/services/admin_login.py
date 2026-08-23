"""Administrator login audit trail."""

from __future__ import annotations

from uuid import UUID, uuid4

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AdminLoginLog, UserRole
from app.services.admin_permissions import STAFF_ROLES
from app.services.client_ip import get_client_ip


def is_staff_role(role: UserRole) -> bool:
    return role in STAFF_ROLES


def _client_meta(request: Request | None) -> tuple[str, str]:
    if request is None:
        return "", ""
    ip = get_client_ip(request)
    ua = (request.headers.get("user-agent") or "")[:255]
    return ip, ua


async def record_staff_login(
    session: AsyncSession,
    *,
    user_id: UUID,
    request: Request | None = None,
    success: bool = True,
    failure_reason: str = "",
) -> AdminLoginLog:
    ip, ua = _client_meta(request)
    entry = AdminLoginLog(
        id=uuid4(),
        user_id=user_id,
        ip_address=ip,
        user_agent=ua,
        success=success,
        failure_reason=failure_reason[:120],
    )
    session.add(entry)
    return entry
