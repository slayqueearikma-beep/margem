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
    RefreshRequest,
    SignupOtpSendRequest,
    SignupOtpSendResponse,
    SignupOtpVerifyRequest,
    TokenResponse,
    UserOut,
    UserRegister,
    UserRegisterFirebase,
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
        f"Open in the MarGem app:\n{deep}\n\n"
        f"Or use this link:\n{web}\n\n"
        f"Code: {token}"
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
    await session.commit()
    return TokenResponse(
        access_token=create_access_token(
            user.id,
            token_version=getattr(user, "token_version", 0),
            session_id=refresh_token_id,
        ),
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(user, has_seller_profile=has_store),
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
        subject="Verify your MarGem email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=verify_token,
            intro="Welcome to MarGem. Verify your email to secure your account.",
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
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        await record_failed_login(session, user, email=payload.email.lower(), ip=ip)
        await session.commit()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if is_account_locked(user):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Account temporarily locked. Try again in {lockout_remaining_seconds(user)} seconds.",
        )
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
    return TokenResponse(
        access_token=create_access_token(
            user.id,
            token_version=getattr(user, "token_version", 0),
            session_id=session_id,
        ),
        refresh_token=new_refresh,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(user, has_seller_profile=has_store),
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

    has_store = await user_has_seller_profile(session, user.id)
    return UserOut.from_user(user, has_seller_profile=has_store)


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
        subject="Verify your MarGem email",
        text_body=_auth_action_body(
            path="/verify-email",
            token=token,
            intro="Verify your MarGem email address.",
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


@router.post("/password-reset/request", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def request_password_reset(
    request: Request,
    payload: EmailRequest,
    session: AsyncSession = Depends(get_db),
) -> None:
    # Always 204 to avoid account enumeration.
    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash:
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
    token = await _issue_auth_token(session, user.id, "password_reset", hours=2)
    await session.commit()
    email_service.send(
        to=user.email,
        subject="Reset your MarGem password",
        text_body=_auth_action_body(
            path="/reset-password",
            token=token,
            intro="Reset your MarGem password. If you did not request this, ignore this email.",
        ),
    )


@router.post("/password-reset/confirm", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
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
        raise HTTPException(status_code=400, detail="Invalid or expired reset token")
    user = await session.get(User, token.user_id)
    if user is None:
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
    return MfaEnrollOut(secret=secret, otpauth_uri=uri)


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
    from app.models import Favorite, Notification, SellerProfile, Subscription

    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()
    favorites = (
        await session.execute(select(Favorite).where(Favorite.user_id == user.id).limit(500))
    ).scalars().all()
    notifications = (
        await session.execute(select(Notification).where(Notification.user_id == user.id).limit(200))
    ).scalars().all()
    subscriptions = (
        await session.execute(select(Subscription).where(Subscription.user_id == user.id))
    ).scalars().all()

    return {
        "exported_at": datetime.now(UTC).isoformat(),
        "user": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "account_type": user.account_type.value,
            "role": user.role.value,
            "email_verified": user.email_verified_at is not None,
            "created_at": user.created_at.isoformat(),
        },
        "seller_profile": (
            {
                "business_name": seller.business_name,
                "city": seller.city,
                "verification_status": seller.verification_status.value,
            }
            if seller
            else None
        ),
        "favorites_count": len(favorites),
        "notifications_count": len(notifications),
        "subscriptions": [
            {
                "status": sub.status.value,
                "period_end": sub.current_period_end.isoformat(),
            }
            for sub in subscriptions
        ],
    }


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit(settings.auth_rate_limit)
async def delete_account(
    request: Request,
    payload: DeleteAccountRequest,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    if not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid password")

    from sqlalchemy import delete as sql_delete, update

    from app.models import (
        AuthToken,
        Conversation,
        Favorite,
        Message,
        MfaFactor,
        MfaRecoveryCode,
        Notification,
        RecentlyViewed,
        Review,
        SavedSearch,
        SellerFollow,
        Subscription,
        UserBlock,
    )
    from app.models.community import (
        CommunityMembership,
        CommunityMessage,
        CommunityReaction,
        CommunityReport,
        CommunityUserBlock,
        CommunityUserMute,
    )
    from app.models.community import (
        CommunityMembership,
        CommunityMessage,
        CommunityMessageStatus,
        CommunityReaction,
        CommunityReport,
    )

    seller = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    profile = seller.scalar_one_or_none()

    # Remove message history the user authored, then any peer conversations they belong to.
    await session.execute(sql_delete(Message).where(Message.sender_id == user.id))
    peer_conversations = (
        await session.execute(
            select(Conversation.id).where(
                (Conversation.participant_a_id == user.id) | (Conversation.participant_b_id == user.id)
            )
        )
    ).scalars().all()
    if peer_conversations:
        await session.execute(sql_delete(Message).where(Message.conversation_id.in_(peer_conversations)))
        await session.execute(sql_delete(Conversation).where(Conversation.id.in_(peer_conversations)))

    # Community chat: remove authored content and membership links (soft-delete keeps user row).
    user_messages = (
        await session.execute(select(CommunityMessage.id).where(CommunityMessage.sender_id == user.id))
    ).scalars().all()
    if user_messages:
        await session.execute(sql_delete(CommunityReaction).where(CommunityReaction.message_id.in_(user_messages)))
        await session.execute(sql_delete(CommunityReport).where(CommunityReport.message_id.in_(user_messages)))
    await session.execute(sql_delete(CommunityMessage).where(CommunityMessage.sender_id == user.id))
    await session.execute(sql_delete(CommunityReport).where(CommunityReport.reporter_id == user.id))
    await session.execute(sql_delete(CommunityMembership).where(CommunityMembership.user_id == user.id))
    await session.execute(sql_delete(CommunityUserBlock).where(CommunityUserBlock.blocker_id == user.id))
    await session.execute(sql_delete(CommunityUserBlock).where(CommunityUserBlock.blocked_id == user.id))
    await session.execute(sql_delete(CommunityUserMute).where(CommunityUserMute.muter_id == user.id))
    await session.execute(sql_delete(CommunityUserMute).where(CommunityUserMute.muted_id == user.id))
    await session.execute(sql_delete(UserBlock).where(UserBlock.blocker_id == user.id))
    await session.execute(sql_delete(UserBlock).where(UserBlock.blocked_id == user.id))

    if profile is not None:
        from app.models import Product, SellerCategory, Service

        # Clear association + owned rows before deleting the storefront (no ON DELETE CASCADE).
        await session.execute(sql_delete(SellerCategory).where(SellerCategory.seller_id == profile.id))
        await session.execute(sql_delete(Product).where(Product.seller_id == profile.id))
        await session.execute(sql_delete(Service).where(Service.seller_id == profile.id))
        await session.execute(sql_delete(Review).where(Review.seller_id == profile.id))
        await session.delete(profile)

    for model, column in (
        (Favorite, Favorite.user_id),
        (SellerFollow, SellerFollow.user_id),
        (SavedSearch, SavedSearch.user_id),
        (RecentlyViewed, RecentlyViewed.user_id),
        (Notification, Notification.user_id),
        (Subscription, Subscription.user_id),
        (AuthToken, AuthToken.user_id),
        (Review, Review.buyer_id),
        (MfaFactor, MfaFactor.user_id),
        (MfaRecoveryCode, MfaRecoveryCode.user_id),
        (CommunityMembership, CommunityMembership.user_id),
        (CommunityReaction, CommunityReaction.user_id),
        (CommunityReport, CommunityReport.reporter_id),
    ):
        await session.execute(sql_delete(model).where(column == user.id))

    # Anonymize community messages instead of hard-deleting (preserves thread structure).
    await session.execute(
        update(CommunityMessage)
        .where(CommunityMessage.sender_id == user.id)
        .values(
            body="[deleted]",
            attachments=[],
            mentions=[],
            hashtags=[],
            status=CommunityMessageStatus.DELETED,
            deleted_at=datetime.now(UTC),
            deleted_by_id=user.id,
        )
    )

    await revoke_all_refresh_tokens(session, user.id)
    user.status = UserStatus.DELETED
    user.email = f"deleted+{user.id}@invalid.local"
    user.display_name = "Deleted user"
    user.phone = ""
    user.password_hash = None
    user.firebase_uid = f"deleted-{user.id}"
    user.email_verified_at = None
    user.mfa_enabled = False
    user.is_premium = False
    user.premium_until = None
    await session.commit()
    log_security_event("account_deleted", user_id=str(user.id))
