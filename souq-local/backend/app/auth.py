import secrets
from uuid import UUID

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.models import User
from app.services.security import decode_access_token

security = HTTPBearer(auto_error=False)


async def _resolve_user_from_credentials(
    credentials: HTTPAuthorizationCredentials | None,
    session: AsyncSession,
    *,
    required: bool,
) -> User | None:
    if (
        settings.auth_dev_bypass
        and settings.app_env in {"development", "dev"}
    ):
        result = await session.execute(select(User).limit(1))
        user = result.scalar_one_or_none()
        if user is None and required:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="No users in database. Register first via POST /auth/register",
            )
        return user

    if credentials is None:
        if required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
        return None

    token = credentials.credentials

    # MarGem JWT (email/password accounts)
    decoded = decode_access_token(token)
    if decoded is not None:
        user_id, token_version, session_id = decoded
        result = await session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            if required:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
            return None
        if getattr(user, "token_version", 0) != token_version:
            if required:
                raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token revoked")
            return None
        if session_id is not None:
            from app.models import RefreshToken

            refresh_row = await session.get(RefreshToken, session_id)
            if refresh_row is None or refresh_row.user_id != user.id or refresh_row.revoked:
                if required:
                    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token revoked")
                return None
        return user

    # Invalid/expired local JWTs must not fall through to Firebase and surface 503
    # when Firebase is intentionally unset (email/password-only deployments).
    if not settings.firebase_credentials_path:
        if required:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        return None

    # Firebase ID token (mobile Firebase Auth)
    try:
        firebase_uid = await verify_firebase_token(token)
    except HTTPException:
        if required:
            raise
        return None

    result = await session.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()
    if user is None:
        if required:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not registered")
        return None
    return user


async def resolve_user_from_access_token(token: str, session: AsyncSession) -> User | None:
    """Validate a bearer JWT and return the user, or None when invalid/revoked."""
    decoded = decode_access_token(token)
    if decoded is None:
        return None
    user_id, token_version, session_id = decoded
    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        return None
    if getattr(user, "token_version", 0) != token_version:
        return None
    if session_id is not None:
        from app.models import RefreshToken

        refresh_row = await session.get(RefreshToken, session_id)
        if refresh_row is None or refresh_row.user_id != user.id or refresh_row.revoked:
            return None
    return await _enforce_account_state(user, session)


async def _enforce_account_state(user: User, session: AsyncSession) -> User:
    """Reject suspended/deleted accounts and soft-expire premium flags."""
    from datetime import UTC, datetime

    from app.models import SellerProfile, UserStatus
    from app.services.premium import is_premium_active

    if getattr(user, "status", None) == UserStatus.SUSPENDED:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account suspended")
    if getattr(user, "status", None) == UserStatus.DELETED:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account deleted")

    premium_until = getattr(user, "premium_until", None)
    if user.is_premium and not is_premium_active(
        is_premium=True, premium_until=premium_until
    ):
        user.is_premium = False
        seller = (
            await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
        ).scalar_one_or_none()
        if seller is not None and seller.is_premium:
            seller.is_premium = False
        await session.commit()
        await session.refresh(user)
    return user


_LEGAL_ACCEPTANCE_EXEMPT_EXACT = (
    "/auth/me",
    "/auth/logout",
    "/auth/logout-all",
    "/auth/refresh",
    "/auth/register",
    "/auth/login",
    "/auth/register-firebase",
    "/auth/signup/otp/send",
    "/auth/signup/otp/verify",
    "/auth/mfa/login",
    "/legal/accept",
    "/legal/accept/status",
    "/auth/legal/accept",
    "/auth/legal/accept/status",
    "/privacy/consents",
    "/privacy/requests",
)

_LEGAL_ACCEPTANCE_EXEMPT_PREFIXES = (
    "/auth/sessions",
    "/auth/verify-email/",
    "/auth/password-reset/",
    "/auth/mfa/",
    "/legal/",
    "/privacy/",
)


def _requires_legal_acceptance(path: str) -> bool:
    if path in _LEGAL_ACCEPTANCE_EXEMPT_EXACT:
        return False
    if any(path.startswith(prefix) for prefix in _LEGAL_ACCEPTANCE_EXEMPT_PREFIXES):
        return False
    return True


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_db),
) -> User:
    user = await _resolve_user_from_credentials(credentials, session, required=True)
    assert user is not None
    user = await _enforce_account_state(user, session)
    if _requires_legal_acceptance(request.url.path):
        from app.services.legal_acceptance import get_pending_policy_ids

        pending = await get_pending_policy_ids(session, user.id)
        if pending:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="legal_acceptance_required",
            )
    return user


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    session: AsyncSession = Depends(get_db),
) -> User | None:
    user = await _resolve_user_from_credentials(credentials, session, required=False)
    if user is None:
        return None
    return await _enforce_account_state(user, session)


async def require_verified_email(user: User = Depends(get_current_user)) -> User:
    """Gate abuse-prone production actions behind a verified email address."""
    if (
        settings.require_verified_email
        and settings.app_env in {"production", "prod"}
        and user.email_verified_at is None
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Verify your email address before performing this action",
        )
    return user


async def verify_firebase_token(token: str) -> str:
    try:
        import firebase_admin
        from firebase_admin import auth, credentials

        if not firebase_admin._apps:
            if settings.firebase_credentials_path:
                cred = credentials.Certificate(settings.firebase_credentials_path)
                firebase_admin.initialize_app(cred)
            else:
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Firebase not configured",
                )

        decoded = auth.verify_id_token(token)
        return decoded["uid"]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc


async def user_has_seller_profile(session: AsyncSession, user_id) -> bool:
    from app.models import SellerProfile

    result = await session.execute(select(SellerProfile.id).where(SellerProfile.user_id == user_id).limit(1))
    return result.scalar_one_or_none() is not None


async def require_seller(user: User = Depends(get_current_user), session: AsyncSession = Depends(get_db)) -> User:
    """Require a storefront capability (SellerProfile), not a permanently XOR'd account type."""
    from app.models import AccountType

    if await user_has_seller_profile(session, user.id):
        return user
    # Legacy: seller accounts mid-onboarding before profile creation still pass.
    if user.account_type == AccountType.PROVIDER:
        return user
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Seller storefront required")


async def require_buyer(user: User = Depends(get_current_user)) -> User:
    """Any authenticated non-deleted user may act as a buyer (dual-mode accounts)."""
    return user


async def require_buyer_premium(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> User:
    """Require an active Dribex Plus (buyer_premium) subscription."""
    from app.services.subscription_service import user_has_buyer_premium

    if not await user_has_buyer_premium(session, user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Dribex Plus subscription required",
        )
    return user


async def require_admin(user: User = Depends(get_current_user)) -> User:
    from app.models import UserRole

    if user.role != UserRole.ADMIN:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    _enforce_staff_mfa(user)
    return user


async def require_staff(user: User = Depends(get_current_user)) -> User:
    """Admin or support — read-oriented staff tools only."""
    from app.models import UserRole

    if user.role not in {UserRole.ADMIN, UserRole.SUPPORT}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff access required")
    _enforce_staff_mfa(user)
    return user


def _enforce_staff_mfa(user: User) -> None:
    if not settings.staff_mfa_required and not settings.admin_require_staff_mfa:
        return
    if settings.app_env not in {"production", "prod", "staging", "preprod"} and not settings.admin_require_staff_mfa:
        return
    if not user.mfa_enabled:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff accounts must enable MFA before accessing admin tools",
        )


def new_local_firebase_uid() -> str:
    return f"local-{secrets.token_hex(16)}"
