import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, new_local_firebase_uid, security
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AccountType, AuthToken, RefreshToken, SellerProfile, User, UserRole, UserStatus
from app.schemas import (
    ChangePasswordRequest,
    DeleteAccountRequest,
    LoginRequest,
    LogoutRequest,
    MfaCodeRequest,
    MfaConfirmOut,
    MfaDisableRequest,
    MfaEnrollOut,
    MfaLoginRequest,
    ProfilePhotoUpdate,
    RefreshRequest,
    SignupOtpSendRequest,
    SignupOtpSendResponse,
    SignupOtpVerifyRequest,
    TokenResponse,
    UserOut,
    UserRegister,
    UserRegisterFirebase,
    UserSelfUpdate,
)
from app.services.audit import log_security_event
from app.services.client_ip import get_client_ip
from app.services.email import email_service
from app.services.login_lockout import (
    is_account_locked,
    lockout_remaining_seconds,
    record_failed_login,
    record_successful_login,
)
from app.services.mfa import (
    begin_totp_enrollment,
    confirm_totp_enrollment,
    disable_mfa,
    verify_user_mfa,
)
from app.services.signup_verification import consume_signup_proof, send_signup_otp, verify_signup_otp
from app.services.password_policy import validate_password_strength
from app.services.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    issue_refresh_token,
    revoke_all_refresh_tokens,
    revoke_refresh_token,
    rotate_refresh_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _request_ip(request: Request) -> str:
    return get_client_ip(request)


def _auth_action_body(*, path: str, token: str, intro: str) -> str:
    """Include HTTPS web + custom-scheme deep links so mobile opens the app with the token."""
    base = settings.public_app_url.rstrip("/")
    web = f"{base}{path}?token={token}"
    deep = f"margem://app{path}?token={token}"
    return (
        f"{intro}\n\n"
        f"Open in the Dribex app:\n{deep}\n\n"
        f"Or use this link:\n{web}\n\n"
        f"Code: {token}"
    )


def _password_reset_email_body(*, token: str) -> str:
    """Password-reset email — link only in body (raw token never logged by email service)."""
    base = settings.public_app_url.rstrip("/")
    if settings.app_env in {"production", "prod", "staging", "preprod", "preview"}:
        if not base.startswith("https://"):
            raise ValueError("PUBLIC_APP_URL must use HTTPS for password reset links")
    web = f"{base}/reset-password?token={token}"
    deep = f"margem://app/reset-password?token={token}"
    hours = settings.password_reset_expire_hours
    support = settings.smtp_from or "Dribex Support"
    return (
        "Dribex — Password reset\n\n"
        "We received a request to reset the password for your Dribex account.\n\n"
        f"Open in the Dribex app:\n{deep}\n\n"
        f"Or reset in your browser:\n{web}\n\n"
        f"This link expires in {hours} hour(s) and can only be used once.\n\n"
        "If you did not request a password reset, you can ignore this email. "
        "Your password will not change unless you use the link above.\n\n"
        f"Questions? Contact us at {support}."
    )


class EmailRequest(BaseModel):
    email: EmailStr


class TokenConfirmRequest(BaseModel):
    # Email verification uses a six-digit code; legacy deep-link tokens remain
    # accepted until they expire.
    token: str = Field(min_length=6, max_length=256)


class PasswordResetConfirm(BaseModel):
    token: str = Field(min_length=20, max_length=256)
    new_password: str = Field(min_length=8, max_length=128)


class PasswordResetRequestResponse(BaseModel):
    message: str


GENERIC_PASSWORD_RESET_MESSAGE = (
    "If an account exists for this email address, we have sent instructions to reset your password."
)
_MAX_PASSWORD_RESET_ATTEMPTS = 5


class SessionOut(BaseModel):
    id: UUID
    device_name: str
    ip_address: str
    user_agent: str
    created_at: datetime
    last_seen_at: datetime | None
    current: bool = False


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


async def _issue_auth_token(
    session: AsyncSession,
    user_id: UUID,
    purpose: str,
    *,
    hours: int | None = None,
    minutes: int | None = None,
) -> str:
    ttl = timedelta(hours=hours or 0, minutes=minutes or 0)
    if hours is None and minutes is None:
        ttl = timedelta(hours=24)
    # A short code is convenient for users, but the token hash is globally
    # unique. Generate and reserve it inside a savepoint to safely retry the
    # rare six-digit collision without rolling back the caller's transaction.
    for _ in range(20):
        plain = (
            f"{secrets.randbelow(1_000_000):06d}"
            if purpose == "email_verify"
            else secrets.token_urlsafe(32)
        )
        try:
            async with session.begin_nested():
                session.add(
                    AuthToken(
                        id=uuid4(),
                        user_id=user_id,
                        purpose=purpose,
                        token_hash=_hash_token(plain),
                        expires_at=datetime.now(UTC) + ttl,
                    )
                )
                await session.flush()
            return plain
        except IntegrityError:
            continue
    raise RuntimeError("Could not allocate a unique authentication token")


async def _token_response(session: AsyncSession, user: User, request: Request | None = None) -> TokenResponse:
    from app.auth import user_has_seller_profile

    device = ""
    ip = ""
    ua = ""
    if request is not None:
        ip = get_client_ip(request)
        ua = (request.headers.get("user-agent") or "")[:255]
        device = (request.headers.get("x-device-name") or ua[:80] or "Device")[:120]

    refresh_token, refresh_token_id = await issue_refresh_token(session, user.id)
    # Attach device metadata to newest refresh token
    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked.is_(False))
        .order_by(RefreshToken.created_at.desc())
        .limit(1)
    )
    stored = result.scalar_one_or_none()
    if stored is not None:
        stored.device_name = device
        stored.ip_address = ip
        stored.user_agent = ua
        stored.last_seen_at = datetime.now(UTC)

    user.last_login_at = datetime.now(UTC)
    has_store = await user_has_seller_profile(session, user.id)
    from app.services.legal_acceptance import get_pending_policy_ids

    pending = await get_pending_policy_ids(session, user.id)
    await session.commit()
    return TokenResponse(
        access_token=create_access_token(
            user.id,
            token_version=getattr(user, "token_version", 0),
            session_id=refresh_token_id,
        ),
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(
            user,
            has_seller_profile=has_store,
            legal_acceptance_complete=not pending,
            pending_legal_policies=pending,
        ),
    )


def _role_for_account(account_type: AccountType) -> UserRole:
    return UserRole.PROVIDER if account_type == AccountType.PROVIDER else UserRole.CUSTOMER


class SignupOtpProofResponse(BaseModel):
    signup_proof: str


@router.post("/signup/otp/send", response_model=SignupOtpSendResponse)
@limiter.limit(settings.auth_rate_limit)
async def signup_otp_send(
    request: Request,
    payload: SignupOtpSendRequest,
    session: AsyncSession = Depends(get_db),
) -> SignupOtpSendResponse:
    _ = request
    result = await send_signup_otp(
        session,
        email=str(payload.email),
        phone=payload.phone,
        channel=payload.channel,
    )
    return SignupOtpSendResponse(**result)


@router.post("/signup/otp/verify", response_model=SignupOtpProofResponse)
@limiter.limit(settings.signup_otp_verify_rate_limit)
async def signup_otp_verify(
    request: Request,
    payload: SignupOtpVerifyRequest,
    session: AsyncSession = Depends(get_db),
) -> SignupOtpProofResponse:
    _ = request
    proof = await verify_signup_otp(
        session,
        email=str(payload.email),
        code=payload.code,
        channel=payload.channel,
    )
    return SignupOtpProofResponse(signup_proof=proof)


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register(
    request: Request,
    payload: UserRegister,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    email = payload.email.lower()
    await consume_signup_proof(session, email=email, proof=payload.signup_proof)
    existing = await session.execute(select(User).where(User.email == email))
    if existing.scalar_one_or_none():
        log_security_event("register_conflict", email=email)
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    account_type = AccountType(payload.account_type.value)
    user = User(
        firebase_uid=new_local_firebase_uid(),
        email=email,
        password_hash=hash_password(payload.password),
        account_type=account_type,
        display_name=payload.display_name.strip(),
        role=_role_for_account(account_type),
        status=UserStatus.ACTIVE,
    )
    session.add(user)
    await session.flush()

    verify_token = await _issue_auth_token(session, user.id, "email_verify", minutes=15)
    delivery = email_service.send(
        to=user.email,
        subject="Verify your Dribex email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=verify_token,
            intro="Welcome to Dribex. Verify your email to secure your account.",
        ),
    )
    log_security_event("register_success", user_id=str(user.id), account_type=user.account_type.value)

    response = await _token_response(session, user, request)
    # TokenResponse schema is fixed; verification tokens are delivered by email / logs only.
    _ = delivery
    return response


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.auth_rate_limit)
async def login(
    request: Request,
    payload: LoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    ip = _request_ip(request)
    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is not None and is_account_locked(user):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Account temporarily locked. Try again in {lockout_remaining_seconds(user)} seconds.",
        )
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        await record_failed_login(session, user, email=payload.email.lower(), ip=ip)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    await record_successful_login(session, user)

    if user.mfa_enabled:
        mfa_token = await _issue_auth_token(session, user.id, "mfa_challenge", minutes=5)
        await session.commit()
        log_security_event("login_mfa_challenge", user_id=str(user.id))
        return TokenResponse(
            mfa_required=True,
            mfa_token=mfa_token,
            expires_in=300,
            user=UserOut.from_user(user, has_seller_profile=False),
        )

    log_security_event("login_success", user_id=str(user.id))
    return await _token_response(session, user, request)


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit(settings.auth_rate_limit)
async def refresh_tokens(
    request: Request,
    payload: RefreshRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    rotated = await rotate_refresh_token(session, payload.refresh_token)
    if rotated is None:
        log_security_event("refresh_failed", client=request.client.host if request.client else "unknown")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user_id, new_refresh, session_id = rotated
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if user.status == UserStatus.SUSPENDED:
        await revoke_all_refresh_tokens(session, user.id)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        await revoke_all_refresh_tokens(session, user.id)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account deleted")

    await session.commit()
    from app.auth import user_has_seller_profile

    has_store = await user_has_seller_profile(session, user.id)
    from app.services.legal_acceptance import get_pending_policy_ids

    pending = await get_pending_policy_ids(session, user.id)
    return TokenResponse(
        access_token=create_access_token(
            user.id,
            token_version=getattr(user, "token_version", 0),
            session_id=session_id,
        ),
        refresh_token=new_refresh,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(
            user,
            has_seller_profile=has_store,
            legal_acceptance_complete=not pending,
            pending_legal_policies=pending,
        ),
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def logout(
    request: Request,
    payload: LogoutRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    await revoke_refresh_token(session, payload.refresh_token)
    await session.commit()
    log_security_event("logout", client=request.client.host if request.client else "unknown")


@router.post("/register-firebase", response_model=UserOut, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register_firebase(
    request: Request,
    payload: UserRegisterFirebase,
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    if settings.app_env not in {"development", "dev"}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not available")

    existing = await session.execute(
        select(User).where((User.firebase_uid == payload.firebase_uid) | (User.email == payload.email.lower()))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

    account_type = AccountType(payload.account_type.value)
    user = User(
        firebase_uid=payload.firebase_uid,
        email=payload.email.lower(),
        account_type=account_type,
        display_name=payload.display_name,
        role=_role_for_account(account_type),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return UserOut.from_user(user, has_seller_profile=False)


@router.get("/me", response_model=UserOut)
async def me(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    from app.auth import user_has_seller_profile
    from app.services.legal_acceptance import get_pending_policy_ids

    has_store = await user_has_seller_profile(session, user.id)
    pending = await get_pending_policy_ids(session, user.id)
    return UserOut.from_user(
        user,
        has_seller_profile=has_store,
        legal_acceptance_complete=not pending,
        pending_legal_policies=pending,
    )


@router.patch("/me", response_model=UserOut)
@limiter.limit(settings.auth_rate_limit)
async def update_me(
    request: Request,
    payload: UserSelfUpdate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    from app.auth import user_has_seller_profile
    from app.services.legal_acceptance import get_pending_policy_ids

    updates = payload.model_dump(exclude_unset=True)
    extra = set(updates.keys()) - {"display_name", "phone"}
    if extra:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Fields not allowed: {', '.join(sorted(extra))}",
        )
    if not updates:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No fields to update")

    if "display_name" in updates and updates["display_name"] is not None:
        name = updates["display_name"].strip()
        if not name:
            raise HTTPException(status_code=400, detail="display_name cannot be empty")
        user.display_name = name[:120]
    if "phone" in updates:
        user.phone = (updates["phone"] or "").strip()[:32]

    await session.commit()
    await session.refresh(user)
    log_security_event("profile_updated", user_id=str(user.id), fields=",".join(sorted(updates.keys())))
    has_store = await user_has_seller_profile(session, user.id)
    pending = await get_pending_policy_ids(session, user.id)
    return UserOut.from_user(
        user,
        has_seller_profile=has_store,
        legal_acceptance_complete=not pending,
        pending_legal_policies=pending,
    )


@router.post("/me/password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def change_password(
    request: Request,
    payload: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash or not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid current password")
    if payload.current_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the current password",
        )
    user.password_hash = hash_password(payload.new_password)
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("password_changed", user_id=str(user.id))


@router.put("/me/profile-photo", response_model=UserOut)
@limiter.limit("20/minute")
async def update_profile_photo(
    request: Request,
    payload: ProfilePhotoUpdate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    from app.auth import user_has_seller_profile
    from app.services.legal_acceptance import get_pending_policy_ids
    from app.services.media_registry import register_media_object, require_registered_media, supersede_media_url
    from app.services.storage_provider import get_storage_provider

    provider = get_storage_provider()
    try:
        validated = provider.validate_owner_url(payload.profile_photo_url, owner_user_id=user.id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if validated:
        try:
            await require_registered_media(session, user_id=user.id, public_url=validated)
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    if validated != (user.profile_photo_url or ""):
        if user.profile_photo_url:
            await supersede_media_url(session, user_id=user.id, old_url=user.profile_photo_url)
        user.profile_photo_url = validated
        if validated:
            await register_media_object(
                session,
                user_id=user.id,
                public_url=validated,
                purpose="profile_photo",
            )
        log_security_event("profile_photo_updated", user_id=str(user.id))

    await session.commit()
    await session.refresh(user)
    pending = await get_pending_policy_ids(session, user.id)
    has_store = await user_has_seller_profile(session, user.id)
    return UserOut.from_user(
        user,
        has_seller_profile=has_store,
        legal_acceptance_complete=not pending,
        pending_legal_policies=pending,
    )


@router.delete("/me/profile-photo", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("20/minute")
async def delete_profile_photo(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    from app.services.media_registry import supersede_media_url

    if user.profile_photo_url:
        await supersede_media_url(session, user_id=user.id, old_url=user.profile_photo_url)
        user.profile_photo_url = ""
        await session.commit()
        log_security_event("profile_photo_deleted", user_id=str(user.id))


@router.post("/logout-all", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def logout_all(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("logout_all", user_id=str(user.id))


@router.get("/sessions", response_model=list[SessionOut])
async def list_sessions(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> list[SessionOut]:
    current_session_id: UUID | None = None
    if credentials is not None:
        decoded = decode_access_token(credentials.credentials)
        if decoded is not None:
            _, _, current_session_id = decoded

    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked.is_(False))
        .order_by(RefreshToken.created_at.desc())
    )
    tokens = list(result.scalars().all())
    return [
        SessionOut(
            id=token.id,
            device_name=token.device_name or "Device",
            ip_address=token.ip_address,
            user_agent=token.user_agent,
            created_at=token.created_at,
            last_seen_at=token.last_seen_at,
            current=current_session_id is not None and token.id == current_session_id,
        )
        for token in tokens
    ]


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def revoke_session(
    session_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    token = await session.get(RefreshToken, session_id)
    if token is None or token.user_id != user.id:
        raise HTTPException(status_code=404, detail="Session not found")
    token.revoked = True
    await session.commit()


@router.post("/verify-email/request", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def request_email_verification(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if user.email_verified_at is not None:
        return
    await session.execute(
        update(AuthToken)
        .where(
            AuthToken.user_id == user.id,
            AuthToken.purpose == "email_verify",
            AuthToken.used_at.is_(None),
        )
        .values(used_at=datetime.now(UTC))
    )
    token = await _issue_auth_token(session, user.id, "email_verify", minutes=15)
    await session.commit()
    email_service.send(
        to=user.email,
        subject="Verify your Dribex email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=token,
            intro="Verify your Dribex email address.",
        ),
    )


_MAX_EMAIL_VERIFY_ATTEMPTS = 10


@router.post("/verify-email/confirm", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("5/minute")
@limiter.limit("30/hour")
async def confirm_email_verification(
    request: Request,
    payload: TokenConfirmRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    result = await session.execute(
        select(AuthToken).where(
            AuthToken.token_hash == _hash_token(payload.token),
            AuthToken.purpose == "email_verify",
        ).with_for_update()
    )
    token = result.scalar_one_or_none()
    if token is None:
        log_security_event(
            "email_verify_failed",
            ip_address=_request_ip(request),
            detail="invalid_or_expired_token",
        )
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")
    if token.used_at is not None or token.expires_at < datetime.now(UTC):
        token.failed_attempts += 1
        if token.failed_attempts >= _MAX_EMAIL_VERIFY_ATTEMPTS:
            token.used_at = datetime.now(UTC)
        await session.commit()
        log_security_event(
            "email_verify_failed",
            ip_address=_request_ip(request),
            detail="invalid_or_expired_token",
        )
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")
    if token.failed_attempts >= _MAX_EMAIL_VERIFY_ATTEMPTS:
        token.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=429, detail="Too many verification attempts")
    user = await session.get(User, token.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Invalid or expired verification token")
    user.email_verified_at = datetime.now(UTC)
    token.used_at = datetime.now(UTC)
    await session.commit()


async def _send_password_reset_if_account_exists(
    session: AsyncSession,
    email: str,
) -> None:
    """Issue a single-use reset token when the account exists; always silent otherwise."""
    result = await session.execute(select(User).where(User.email == email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash or user.status == UserStatus.DELETED:
        return
    await session.execute(
        update(AuthToken)
        .where(
            AuthToken.user_id == user.id,
            AuthToken.purpose == "password_reset",
            AuthToken.used_at.is_(None),
        )
        .values(used_at=datetime.now(UTC))
    )
    token = await _issue_auth_token(
        session,
        user.id,
        "password_reset",
        hours=settings.password_reset_expire_hours,
    )
    await session.commit()
    email_service.send(
        to=user.email,
        subject="Reset your Dribex password",
        text_body=_password_reset_email_body(token=token),
    )


@router.post(
    "/password-reset/request",
    response_model=PasswordResetRequestResponse,
    status_code=status.HTTP_200_OK,
)
@router.post(
    "/forgot-password",
    response_model=PasswordResetRequestResponse,
    status_code=status.HTTP_200_OK,
)
@limiter.limit(settings.password_reset_request_rate_limit)
async def request_password_reset(
    request: Request,
    payload: EmailRequest,
    session: AsyncSession = Depends(get_db),
) -> PasswordResetRequestResponse:
    await _send_password_reset_if_account_exists(session, payload.email)
    return PasswordResetRequestResponse(message=GENERIC_PASSWORD_RESET_MESSAGE)


@router.post("/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.password_reset_confirm_rate_limit)
async def confirm_password_reset(
    request: Request,
    payload: PasswordResetConfirm,
    session: AsyncSession = Depends(get_db),
) -> None:
    try:
        validate_password_strength(payload.new_password)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    result = await session.execute(
        select(AuthToken).where(
            AuthToken.token_hash == _hash_token(payload.token),
            AuthToken.purpose == "password_reset",
        ).with_for_update()
    )
    token = result.scalar_one_or_none()
    if token is None or token.used_at is not None or token.expires_at < datetime.now(UTC):
        if token is not None:
            token.failed_attempts += 1
            if token.failed_attempts >= _MAX_PASSWORD_RESET_ATTEMPTS:
                token.used_at = datetime.now(UTC)
            await session.commit()
        log_security_event(
            "password_reset_failed",
            ip_address=_request_ip(request),
            detail="invalid_or_expired_token",
        )
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    if token.failed_attempts >= _MAX_PASSWORD_RESET_ATTEMPTS:
        token.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    user = await session.get(User, token.user_id)
    if user is None or user.status == UserStatus.DELETED:
        token.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    user.password_hash = hash_password(payload.new_password)
    token.used_at = datetime.now(UTC)
    await revoke_all_refresh_tokens(session, user.id)
    await session.commit()
    log_security_event("password_reset", user_id=str(user.id))


@router.post("/mfa/login", response_model=TokenResponse)
@limiter.limit("10/minute")
async def complete_mfa_login(
    request: Request,
    payload: MfaLoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    result = await session.execute(
        select(AuthToken).where(
            AuthToken.token_hash == _hash_token(payload.mfa_token),
            AuthToken.purpose == "mfa_challenge",
        ).with_for_update()
    )
    challenge = result.scalar_one_or_none()
    if challenge is None or challenge.used_at is not None or challenge.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=401, detail="Invalid or expired MFA challenge")
    user = await session.get(User, challenge.user_id)
    if user is None or not user.mfa_enabled:
        raise HTTPException(status_code=401, detail="Invalid or expired MFA challenge")
    if not await verify_user_mfa(session, user, payload.code):
        challenge.failed_attempts += 1
        if challenge.failed_attempts >= 5:
            challenge.used_at = datetime.now(UTC)
        await session.commit()
        raise HTTPException(status_code=401, detail="Invalid MFA code")
    challenge.used_at = datetime.now(UTC)
    log_security_event("login_success", user_id=str(user.id), mfa=True)
    return await _token_response(session, user, request)


@router.post("/mfa/enroll", response_model=MfaEnrollOut)
@limiter.limit(settings.auth_rate_limit)
async def enroll_mfa(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MfaEnrollOut:
    try:
        secret, uri = await begin_totp_enrollment(session, user)
        await session.commit()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return MfaEnrollOut(otpauth_uri=uri)


@router.post("/mfa/confirm", response_model=MfaConfirmOut)
@limiter.limit(settings.auth_rate_limit)
async def confirm_mfa(
    request: Request,
    payload: MfaCodeRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MfaConfirmOut:
    try:
        recovery_codes = await confirm_totp_enrollment(session, user, payload.code)
        await session.commit()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return MfaConfirmOut(recovery_codes=recovery_codes)


@router.post("/mfa/disable", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def disable_user_mfa(
    request: Request,
    payload: MfaDisableRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid password")
    try:
        await disable_mfa(session, user, code=payload.code)
        await session.commit()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/me/export")
@limiter.limit("3/hour")
async def export_my_data(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    from app.services.data_export import build_user_data_export

    return await build_user_data_export(session, user)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def delete_account(
    request: Request,
    payload: DeleteAccountRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash:
        if payload.confirmation.strip() != "DELETE":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="confirmation must be DELETE")
    elif not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid password")

    from app.services.account_deletion import delete_user_account

    await delete_user_account(session, user)
    await session.commit()
