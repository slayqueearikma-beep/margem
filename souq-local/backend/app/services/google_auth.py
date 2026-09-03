"""Verify Google ID tokens and resolve Dribex accounts."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Literal

from fastapi import HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import AccountType, User, UserRole, UserStatus
from app.services.audit import log_security_event
from app.services.login_lockout import is_account_locked, lockout_remaining_seconds, record_successful_login
from app.services.security import verify_password

_GOOGLE_ISSUERS = frozenset({"accounts.google.com", "https://accounts.google.com"})


@dataclass(frozen=True)
class GoogleIdentity:
    sub: str
    email: str
    email_verified: bool
    display_name: str


@dataclass(frozen=True)
class GoogleAuthOutcome:
    kind: Literal["session", "link_required", "mfa_required"]
    user: User | None = None
    email_hint: str | None = None
    mfa_token: str | None = None


def google_firebase_uid(google_sub: str) -> str:
    return f"google-{google_sub}"


def verify_google_id_token(id_token: str) -> GoogleIdentity:
    """Validate a Google ID token server-side (signature, iss, aud, exp, email)."""
    if not settings.google_oauth_client_ids:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not configured",
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Sign-In is not available",
        ) from exc

    request = google_requests.Request()
    last_error: Exception | None = None
    idinfo: dict | None = None
    for audience in settings.google_oauth_client_ids:
        try:
            idinfo = google_id_token.verify_oauth2_token(id_token, request, audience=audience)
            break
        except ValueError as exc:
            last_error = exc
            continue

    if idinfo is None:
        log_security_event("google_auth_invalid_token")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google credential",
        ) from last_error

    issuer = str(idinfo.get("iss") or "")
    if issuer not in _GOOGLE_ISSUERS:
        log_security_event("google_auth_invalid_issuer")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google credential")

    sub = str(idinfo.get("sub") or "").strip()
    email = str(idinfo.get("email") or "").strip().lower()
    if not sub or not email or "@" not in email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google credential")

    email_verified = bool(idinfo.get("email_verified"))
    if not email_verified:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google email address is not verified",
        )

    display_name = str(idinfo.get("name") or idinfo.get("given_name") or "").strip()
    return GoogleIdentity(sub=sub, email=email, email_verified=email_verified, display_name=display_name)


def _mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    if len(local) <= 2:
        masked_local = local[:1] + "*"
    else:
        masked_local = local[:2] + "***"
    return f"{masked_local}@{domain}"


async def _ensure_user_active(user: User) -> None:
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google credential")


async def resolve_google_auth(
    session: AsyncSession,
    identity: GoogleIdentity,
    *,
    account_type: AccountType,
    allow_create: bool,
) -> GoogleAuthOutcome:
    """Find, link, or create a Dribex user for a verified Google identity."""
    google_uid = google_firebase_uid(identity.sub)

    by_uid = (
        await session.execute(select(User).where(User.firebase_uid == google_uid))
    ).scalar_one_or_none()
    if by_uid is not None:
        await _ensure_user_active(by_uid)
        return GoogleAuthOutcome(kind="session", user=by_uid)

    by_email = (
        await session.execute(select(User).where(User.email == identity.email))
    ).scalar_one_or_none()
    if by_email is not None:
        await _ensure_user_active(by_email)
        if by_email.firebase_uid == google_uid:
            return GoogleAuthOutcome(kind="session", user=by_email)

        if by_email.firebase_uid.startswith("google-"):
            log_security_event("google_auth_identity_conflict", user_id=str(by_email.id))
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This Google account is linked to another Dribex user",
            )

        if by_email.password_hash:
            return GoogleAuthOutcome(
                kind="link_required",
                email_hint=_mask_email(identity.email),
            )

        by_email.firebase_uid = google_uid
        if by_email.email_verified_at is None:
            by_email.email_verified_at = datetime.now(UTC)
        if identity.display_name and not by_email.display_name:
            by_email.display_name = identity.display_name[:120]
        log_security_event("google_auth_linked_passwordless", user_id=str(by_email.id))
        return GoogleAuthOutcome(kind="session", user=by_email)

    if not allow_create:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Account not found")

    role = UserRole.PROVIDER if account_type == AccountType.PROVIDER else UserRole.CUSTOMER
    user = User(
        firebase_uid=google_uid,
        email=identity.email,
        password_hash=None,
        account_type=account_type,
        display_name=(identity.display_name or identity.email.split("@", 1)[0])[:120],
        role=role,
        status=UserStatus.ACTIVE,
        email_verified_at=datetime.now(UTC),
    )
    session.add(user)
    await session.flush()
    log_security_event("google_auth_register", user_id=str(user.id), account_type=account_type.value)
    return GoogleAuthOutcome(kind="session", user=user)


async def link_google_to_existing_user(
    session: AsyncSession,
    identity: GoogleIdentity,
    *,
    password: str,
) -> User:
    """Link a verified Google identity to an existing email/password account."""
    result = await session.execute(select(User).where(User.email == identity.email))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    if is_account_locked(user):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Account temporarily locked. Try again in {lockout_remaining_seconds(user)} seconds.",
        )

    if not verify_password(password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    google_uid = google_firebase_uid(identity.sub)
    existing_uid = (
        await session.execute(select(User).where(User.firebase_uid == google_uid))
    ).scalar_one_or_none()
    if existing_uid is not None and existing_uid.id != user.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This Google account is already linked to another Dribex user",
        )

    await _ensure_user_active(user)
    user.firebase_uid = google_uid
    if user.email_verified_at is None:
        user.email_verified_at = datetime.now(UTC)
    await record_successful_login(session, user)
    log_security_event("google_auth_linked", user_id=str(user.id))
    return user
