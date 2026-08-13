"""Account-level login lockout after repeated failed attempts."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User
from app.services.audit import log_security_event

_MAX_ATTEMPTS = 5
_LOCKOUT_MINUTES = (1, 5, 15, 60)


def _lockout_duration(attempts: int) -> timedelta:
    tier = min(max(attempts - _MAX_ATTEMPTS, 0), len(_LOCKOUT_MINUTES) - 1)
    return timedelta(minutes=_LOCKOUT_MINUTES[tier])


async def ensure_account_not_locked(user: User) -> None:
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return
    now = datetime.now(UTC)
    if locked_until.tzinfo is None:
        locked_until = locked_until.replace(tzinfo=UTC)
    if locked_until <= now:
        return
    log_security_event("login_locked", user_id=str(user.id))
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail="Too many failed login attempts. Try again later.",
    )


async def record_failed_login(session: AsyncSession, user: User | None, *, email: str) -> None:
    if user is None:
        return
    user.failed_login_attempts = int(getattr(user, "failed_login_attempts", 0) or 0) + 1
    if user.failed_login_attempts >= _MAX_ATTEMPTS:
        duration = _lockout_duration(user.failed_login_attempts)
        user.locked_until = datetime.now(UTC) + duration
        log_security_event(
            "login_lockout_applied",
            user_id=str(user.id),
            attempts=user.failed_login_attempts,
            minutes=int(duration.total_seconds() // 60),
        )
    await session.commit()


async def clear_login_lockout(session: AsyncSession, user: User) -> None:
    user.failed_login_attempts = 0
    user.locked_until = None
