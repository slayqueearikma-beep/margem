"""Per-account login lockout after repeated failed password attempts."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import User
from app.services.audit import log_security_event
from app.services.email import SecurityAlertKind, email_service

_LOCKOUT_THRESHOLDS = (5, 15, 30)  # minutes after 5th, 10th, 15th failures within window
_LOCKOUT_WINDOW = timedelta(hours=1)


def is_account_locked(user: User) -> bool:
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return False
    return locked_until > datetime.now(UTC)


def lockout_remaining_seconds(user: User) -> int:
    locked_until = getattr(user, "locked_until", None)
    if locked_until is None:
        return 0
    remaining = (locked_until - datetime.now(UTC)).total_seconds()
    return max(0, int(remaining))


async def record_failed_login(session: AsyncSession, user: User | None, *, email: str, ip: str) -> None:
    if user is None:
        log_security_event("login_failed", email=email, client=ip)
        return

    now = datetime.now(UTC)
    attempts = int(getattr(user, "failed_login_attempts", 0) or 0) + 1
    user.failed_login_attempts = attempts

    if attempts >= settings.login_lockout_threshold:
        tier = min((attempts - settings.login_lockout_threshold) // 5, len(_LOCKOUT_THRESHOLDS) - 1)
        minutes = _LOCKOUT_THRESHOLDS[tier]
        user.locked_until = now + timedelta(minutes=minutes)
        log_security_event(
            "account_locked",
            user_id=str(user.id),
            attempts=attempts,
            minutes=minutes,
            client=ip,
        )
        email_service.queue_security_alert(
            to=user.email,
            alert_type=SecurityAlertKind.ACCOUNT_LOCKED,
            message="Your Dribex account was temporarily locked after repeated failed sign-in attempts.",
            detail_lines=[
                f"Sign-in attempts: {attempts}",
                f"Lockout duration: {minutes} minute(s)",
            ],
            user_id=str(user.id),
        )
    await session.flush()
    log_security_event("login_failed", email=email, user_id=str(user.id), client=ip)


async def record_successful_login(session: AsyncSession, user: User) -> None:
    user.failed_login_attempts = 0
    user.locked_until = None
    await session.flush()
