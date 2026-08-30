"""Six-digit OTP for pre-registration signup verification."""

from __future__ import annotations

import hashlib
import logging
import os
import secrets
from datetime import UTC, datetime, timedelta
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import SignupVerification, User
from app.services.email import email_service

logger = logging.getLogger("margem.signup_otp")

_CODE_TTL = timedelta(minutes=10)
_PROOF_TTL = timedelta(minutes=20)
_MAX_ATTEMPTS = 8


def _hash_value(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    if not local:
        return email
    if len(local) <= 2:
        return f"{local[0]}***@{domain}"
    return f"{local[0]}***{local[-1]}@{domain}"


def _mask_phone(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) < 4:
        return phone
    return f"+{digits[:-9] or ''} {digits[-9:-7]}** *** **{digits[-2:]}" if len(digits) > 9 else f"***{digits[-2:]}"


async def send_signup_otp(
    session: AsyncSession,
    *,
    email: str,
    phone: str,
    channel: str,
) -> dict[str, str]:
    normalized_email = email.strip().lower()
    normalized_phone = phone.strip()
    if channel not in {"email", "phone"}:
        raise HTTPException(status_code=400, detail="Channel must be email or phone")
    if channel == "phone" and not normalized_phone:
        raise HTTPException(status_code=400, detail="Phone number is required for SMS verification")

    existing = await session.execute(select(User).where(User.email == normalized_email))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Email already registered")

    await session.execute(
        update(SignupVerification)
        .where(
            SignupVerification.email == normalized_email,
            SignupVerification.used_at.is_(None),
        )
        .values(used_at=datetime.now(UTC))
    )

    code = f"{secrets.randbelow(1_000_000):06d}"
    row = SignupVerification(
        id=uuid4(),
        email=normalized_email,
        phone=normalized_phone,
        channel=channel,
        code_hash=_hash_value(code),
        expires_at=datetime.now(UTC) + _CODE_TTL,
    )
    session.add(row)
    await session.flush()

    destination = normalized_email if channel == "email" else normalized_phone
    if channel == "email":
        email_service.send(
            to=normalized_email,
            subject="Your MarGem verification code",
            text_body=(
                "Your MarGem signup verification code is:\n\n"
                f"{code}\n\n"
                "This code expires in 10 minutes. If you did not request this, ignore this email."
            ),
        )
    else:
        logger.info(
            "signup_sms_otp to=%s (SMS provider not configured — code not logged)",
            destination,
        )

    await session.commit()
    masked = _mask_email(normalized_email) if channel == "email" else _mask_phone(normalized_phone)
    result = {"channel": channel, "destination_masked": masked}
    if settings.app_env in {"development", "dev", "test"} or os.environ.get(
        "PYTEST_CURRENT_TEST"
    ):
        result["dev_code"] = code
    return result


async def verify_signup_otp(
    session: AsyncSession,
    *,
    email: str,
    code: str,
    channel: str,
) -> str:
    normalized_email = email.strip().lower()
    normalized_code = code.strip()
    if len(normalized_code) != 6 or not normalized_code.isdigit():
        raise HTTPException(status_code=400, detail="Enter the 6-digit code")

    result = await session.execute(
        select(SignupVerification)
        .where(
            SignupVerification.email == normalized_email,
            SignupVerification.channel == channel,
            SignupVerification.used_at.is_(None),
            SignupVerification.verified_at.is_(None),
        )
        .order_by(SignupVerification.created_at.desc())
        .limit(1)
        .with_for_update()
    )
    row = result.scalar_one_or_none()
    if row is None or row.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")
    if row.failed_attempts >= _MAX_ATTEMPTS:
        row.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=429, detail="Too many verification attempts")

    if _hash_value(normalized_code) != row.code_hash:
        row.failed_attempts += 1
        if row.failed_attempts >= _MAX_ATTEMPTS:
            row.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")

    proof = secrets.token_urlsafe(32)
    row.verified_at = datetime.now(UTC)
    row.proof_token_hash = _hash_value(proof)
    row.expires_at = datetime.now(UTC) + _PROOF_TTL
    await session.commit()
    return proof


async def consume_signup_proof(session: AsyncSession, *, email: str, proof: str) -> None:
    normalized_email = email.strip().lower()
    result = await session.execute(
        select(SignupVerification)
        .where(
            SignupVerification.email == normalized_email,
            SignupVerification.proof_token_hash == _hash_value(proof),
            SignupVerification.verified_at.is_not(None),
            SignupVerification.used_at.is_(None),
        )
        .with_for_update()
    )
    row = result.scalar_one_or_none()
    if row is None or row.expires_at < datetime.now(UTC):
        raise HTTPException(
            status_code=400,
            detail="Signup verification expired. Request a new code and try again.",
        )
    row.used_at = datetime.now(UTC)
    await session.flush()
