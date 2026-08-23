import hashlib
import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, new_local_firebase_uid
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AccountType, AuthToken, RefreshToken, SellerProfile, User, UserRole, UserStatus
from app.schemas import (
    ChangePasswordRequest,
    DeleteAccountRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    TokenResponse,
    UserOut,
    UserRegister,
    UserRegisterFirebase,
)
from app.services.audit import log_security_event
from app.services.client_ip import get_client_ip
from app.services.email import email_service
from app.services.password_policy import validate_password_strength
from app.services.security import (
    create_access_token,
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


async def _issue_auth_token(session: AsyncSession, user_id: UUID, purpose: str, hours: int = 24) -> str:
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
                        expires_at=datetime.now(UTC) + timedelta(hours=hours),
                    )
                )
                await session.flush()
            return plain
        except IntegrityError:
            continue
    raise RuntimeError("Could not allocate a unique authentication token")


async def _token_response(session: AsyncSession, user: User, request: Request | None = None) -> TokenResponse:
    from app.auth import user_has_seller_profile
    from app.services.admin_login import is_staff_role, record_staff_login

    device = ""
    ip = ""
    ua = ""
    if request is not None:
        ip = _request_ip(request)
        ua = (request.headers.get("user-agent") or "")[:255]
        device = (request.headers.get("x-device-name") or ua[:80] or "Device")[:120]

    refresh_token = await issue_refresh_token(session, user.id)
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
    if is_staff_role(user.role):
        await record_staff_login(session, user_id=user.id, request=request, success=True)
    has_store = await user_has_seller_profile(session, user.id)
    await session.commit()
    return TokenResponse(
        access_token=create_access_token(user.id, token_version=getattr(user, "token_version", 0)),
        refresh_token=refresh_token,
        expires_in=settings.jwt_access_expire_minutes * 60,
        user=UserOut.from_user(user, has_seller_profile=has_store),
    )


def _role_for_account(account_type: AccountType) -> UserRole:
    return UserRole.SELLER if account_type == AccountType.SELLER else UserRole.BUYER


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register(
    request: Request,
    payload: UserRegister,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    email = payload.email.lower()
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

    verify_token = await _issue_auth_token(session, user.id, "email_verify", hours=0.25)
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
    from app.services.admin_login import is_staff_role, record_staff_login

    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        if user is not None and is_staff_role(user.role):
            await record_staff_login(
                session,
                user_id=user.id,
                request=request,
                success=False,
                failure_reason="invalid_credentials",
            )
            await session.commit()
        log_security_event(
            "login_failed",
            email=payload.email.lower(),
            client=_request_ip(request) or "unknown",
        )
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if user.status == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if user.status == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

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
        log_security_event("refresh_failed", client=_request_ip(request) or "unknown")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user_id, new_refresh = rotated
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
        access_token=create_access_token(user.id, token_version=getattr(user, "token_version", 0)),
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
    log_security_event("logout", client=_request_ip(request) or "unknown")


@router.post("/register-firebase", response_model=UserOut, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register_firebase(
    request: Request,
    payload: UserRegisterFirebase,
    session: AsyncSession = Depends(get_db),
) -> UserOut:
    if settings.app_env in {"production", "prod"} or not settings.debug:
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
) -> list[SessionOut]:
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
            current=False,
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
    token = await _issue_auth_token(session, user.id, "email_verify", hours=0.25)
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


@router.get("/me/export")
@limiter.limit("5/hour")
async def export_my_data(
    request: Request,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    """GDPR/Law 09-08 data portability — returns a JSON export of user data."""
    from app.auth import user_has_seller_profile
    from app.models import Favorite, Notification, Review, SavedSearch, SellerFollow, Subscription
    from sqlalchemy.orm import selectinload

    has_store = await user_has_seller_profile(session, user.id)

    favorites = (
        await session.execute(select(Favorite).where(Favorite.user_id == user.id))
    ).scalars().all()
    saved = (
        await session.execute(select(SavedSearch).where(SavedSearch.user_id == user.id))
    ).scalars().all()
    follows = (
        await session.execute(select(SellerFollow).where(SellerFollow.user_id == user.id))
    ).scalars().all()
    reviews = (
        await session.execute(select(Review).where(Review.buyer_id == user.id))
    ).scalars().all()
    notifications = (
        await session.execute(select(Notification).where(Notification.user_id == user.id).limit(100))
    ).scalars().all()
    subscriptions = (
        await session.execute(
            select(Subscription).where(Subscription.user_id == user.id).options(
                selectinload(Subscription.plan)
            )
        )
    ).scalars().all()

    seller_data = None
    if has_store:
        profile = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
        ).scalar_one_or_none()
        if profile:
            seller_data = {
                "business_name": profile.business_name,
                "city": profile.city,
                "verification_status": profile.verification_status.value,
            }

    return {
        "exported_at": datetime.now(UTC).isoformat(),
        "account": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "account_type": user.account_type.value,
            "role": user.role.value,
            "status": user.status.value,
            "email_verified": user.email_verified_at is not None,
            "is_premium": user.is_premium,
            "premium_until": user.premium_until.isoformat() if user.premium_until else None,
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "has_seller_profile": has_store,
        },
        "seller": seller_data,
        "favorites_count": len(favorites),
        "saved_searches": [
            {"query": s.query, "city": s.city, "category": s.category} for s in saved
        ],
        "follows_count": len(follows),
        "reviews_count": len(reviews),
        "notifications_count": len(notifications),
        "subscriptions": [
            {
                "plan_code": sub.plan.code if sub.plan else "",
                "status": sub.status.value,
                "started_at": sub.current_period_start.isoformat() if sub.current_period_start else None,
                "expires_at": sub.current_period_end.isoformat() if sub.current_period_end else None,
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

    from app.services.account_lifecycle import soft_delete_user

    await soft_delete_user(session, user)
    await session.commit()
