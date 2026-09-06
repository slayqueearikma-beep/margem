"""TOTP MFA enrollment, verification, and recovery codes."""

from __future__ import annotations

import base64
import hashlib
import secrets
from datetime import UTC, datetime
from uuid import UUID, uuid4

import pyotp
from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import MfaFactor, MfaRecoveryCode, User
from app.services.audit import log_security_event

_ISSUER = "Dribex"
_RECOVERY_CODE_COUNT = 8


def _fernet() -> Fernet:
    digest = hashlib.sha256(settings.mfa_encryption_key.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_secret(plain: str) -> str:
    return _fernet().encrypt(plain.encode("utf-8")).decode("utf-8")


def decrypt_secret(encrypted: str) -> str:
    try:
        return _fernet().decrypt(encrypted.encode("utf-8")).decode("utf-8")
    except InvalidToken as exc:
        raise ValueError("Invalid MFA secret") from exc


def generate_totp_secret() -> str:
    return pyotp.random_base32()


def totp_for_secret(secret: str) -> pyotp.TOTP:
    return pyotp.TOTP(secret, interval=30)


def provisioning_uri(secret: str, *, email: str) -> str:
    return totp_for_secret(secret).provisioning_uri(name=email, issuer_name=_ISSUER)


def verify_totp_code(secret: str, code: str, *, valid_window: int = 1) -> bool:
    normalized = code.strip().replace(" ", "")
    if not normalized.isdigit() or len(normalized) != 6:
        return False
    return totp_for_secret(secret).verify(normalized, valid_window=valid_window)


def _hash_recovery_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _generate_recovery_codes() -> list[str]:
    return [secrets.token_hex(4).upper() for _ in range(_RECOVERY_CODE_COUNT)]


async def get_active_totp_factor(session: AsyncSession, user_id: UUID) -> MfaFactor | None:
    result = await session.execute(
        select(MfaFactor).where(
            MfaFactor.user_id == user_id,
            MfaFactor.factor_type == "totp",
            MfaFactor.disabled_at.is_(None),
            MfaFactor.verified_at.is_not(None),
        )
    )
    return result.scalar_one_or_none()


async def get_pending_totp_factor(session: AsyncSession, user_id: UUID) -> MfaFactor | None:
    result = await session.execute(
        select(MfaFactor).where(
            MfaFactor.user_id == user_id,
            MfaFactor.factor_type == "totp",
            MfaFactor.disabled_at.is_(None),
            MfaFactor.verified_at.is_(None),
        )
    )
    return result.scalar_one_or_none()


async def begin_totp_enrollment(session: AsyncSession, user: User) -> tuple[str, str]:
    if user.mfa_enabled:
        raise ValueError("MFA is already enabled")

    pending = await get_pending_totp_factor(session, user.id)
    if pending is not None:
        secret = decrypt_secret(pending.secret_encrypted)
        return secret, provisioning_uri(secret, email=user.email)

    secret = generate_totp_secret()
    factor = MfaFactor(
        id=uuid4(),
        user_id=user.id,
        factor_type="totp",
        secret_encrypted=encrypt_secret(secret),
    )
    session.add(factor)
    await session.flush()
    return secret, provisioning_uri(secret, email=user.email)


async def confirm_totp_enrollment(session: AsyncSession, user: User, code: str) -> list[str]:
    pending = await get_pending_totp_factor(session, user.id)
    if pending is None:
        raise ValueError("No pending MFA enrollment")

    secret = decrypt_secret(pending.secret_encrypted)
    if not verify_totp_code(secret, code):
        log_security_event("mfa_enroll_failed", user_id=str(user.id))
        raise ValueError("Invalid verification code")

    pending.verified_at = datetime.now(UTC)
    user.mfa_enabled = True

    await session.execute(
        update(MfaRecoveryCode).where(MfaRecoveryCode.user_id == user.id).values(used_at=datetime.now(UTC))
    )
    plain_codes = _generate_recovery_codes()
    for plain in plain_codes:
        session.add(
            MfaRecoveryCode(
                id=uuid4(),
                user_id=user.id,
                code_hash=_hash_recovery_code(plain),
            )
        )
    await session.flush()
    log_security_event("mfa_enabled", user_id=str(user.id))
    return plain_codes


async def verify_user_mfa(session: AsyncSession, user: User, code: str) -> bool:
    factor = await get_active_totp_factor(session, user.id)
    if factor is None:
        return False

    secret = decrypt_secret(factor.secret_encrypted)
    if verify_totp_code(secret, code):
        return True

    normalized = code.strip().replace(" ", "").upper()
    if len(normalized) == 8:
        result = await session.execute(
            select(MfaRecoveryCode).where(
                MfaRecoveryCode.user_id == user.id,
                MfaRecoveryCode.code_hash == _hash_recovery_code(normalized),
                MfaRecoveryCode.used_at.is_(None),
            ).with_for_update()
        )
        recovery = result.scalar_one_or_none()
        if recovery is not None:
            recovery.used_at = datetime.now(UTC)
            await session.flush()
            log_security_event("mfa_recovery_code_used", user_id=str(user.id))
            return True

    log_security_event("mfa_verify_failed", user_id=str(user.id))
    return False


async def disable_mfa(session: AsyncSession, user: User, *, code: str) -> None:
    if not user.mfa_enabled:
        return
    if not await verify_user_mfa(session, user, code):
        raise ValueError("Invalid MFA code")

    factor = await get_active_totp_factor(session, user.id)
    if factor is not None:
        factor.disabled_at = datetime.now(UTC)
    user.mfa_enabled = False
    await session.execute(
        update(MfaRecoveryCode).where(MfaRecoveryCode.user_id == user.id).values(used_at=datetime.now(UTC))
    )
    await session.flush()
    log_security_event("mfa_disabled", user_id=str(user.id))
