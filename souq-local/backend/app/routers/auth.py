from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, new_local_firebase_uid
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import AccountType, User
from app.schemas import LoginRequest, TokenResponse, UserOut, UserRegister, UserRegisterFirebase
from app.services.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register(
    request: Request,
    payload: UserRegister,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    existing = await session.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email already registered")

    user = User(
        firebase_uid=new_local_firebase_uid(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        account_type=AccountType(payload.account_type.value),
        display_name=payload.display_name.strip(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


@router.post("/login", response_model=TokenResponse)
@limiter.limit(settings.auth_rate_limit)
async def login(
    request: Request,
    payload: LoginRequest,
    session: AsyncSession = Depends(get_db),
) -> TokenResponse:
    result = await session.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if user is None or not user.password_hash or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, user=UserOut.model_validate(user))


@router.post("/register-firebase", response_model=UserOut, status_code=status.HTTP_201_CREATED)
@limiter.limit(settings.auth_rate_limit)
async def register_firebase(
    request: Request,
    payload: UserRegisterFirebase,
    session: AsyncSession = Depends(get_db),
) -> User:
    """Disabled in production until Firebase ID token verification is implemented."""
    if settings.app_env in {"production", "prod"}:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not available")

    existing = await session.execute(
        select(User).where((User.firebase_uid == payload.firebase_uid) | (User.email == payload.email.lower()))
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")

    user = User(
        firebase_uid=payload.firebase_uid,
        email=payload.email.lower(),
        account_type=AccountType(payload.account_type.value),
        display_name=payload.display_name,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> User:
    return user
