"""MarGem administration API — isolated from public marketplace routes."""

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import require_admin, require_moderator, require_staff, require_super_admin
from app.config import settings
from app.database import get_db
from app.limiter import limiter
from app.models import (
    AdminAuditLog,
    AdminLoginLog,
    Category,
    ContactEvent,
    Favorite,
    Product,
    Report,
    Review,
    SellerProfile,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
    UserRole,
    UserStatus,
    VerificationStatus,
)
from app.routers.seller_ops import AdminPremiumGrant, AdminUserOut, PendingSellerOut
from app.schemas.billing import SubscriptionOut
from app.services.admin_audit import record_admin_action
from app.services.admin_permissions import assert_permission, role_label
from app.services.admin_premium import admin_grant_premium as grant_premium_to_user
from app.services.email import email_service
from app.services.admin_analytics import (
    fetch_daily_growth,
    fetch_dashboard_counts,
    fetch_monthly_growth,
)
from app.services.security import revoke_all_refresh_tokens

router = APIRouter(prefix="/admin", tags=["admin"])


# ── Schemas ───────────────────────────────────────────────────────────────────


class AdminDashboardOut(BaseModel):
    total_users: int
    active_users: int
    new_users_7d: int
    total_businesses: int
    verified_businesses: int
    pending_verifications: int
    total_listings: int
    featured_listings: int
    total_categories: int
    total_reviews: int
    open_reports: int
    premium_subscribers: int
    user_growth_30d: list[dict]
    listing_growth_30d: list[dict]
    recent_activity: list[dict]
    system_status: dict


class AdminUserDetailOut(AdminUserOut):
    phone: str = ""
    last_login_at: datetime | None = None
    email_verified: bool = False


class AdminUserListOut(BaseModel):
    items: list[AdminUserOut]
    total: int
    offset: int
    limit: int


class AdminPaginatedOut(BaseModel):
    total: int
    offset: int
    limit: int


class AdminSellerOut(BaseModel):
    id: UUID
    business_name: str
    city: str
    verification_status: str
    is_active: bool
    is_premium: bool
    user_id: UUID
    created_at: datetime


class AdminProductOut(BaseModel):
    id: UUID
    name: str
    seller_id: UUID
    category_slug: str
    is_hidden: bool
    is_featured: bool
    is_paused: bool
    is_available: bool
    created_at: datetime


class AdminReportOut(BaseModel):
    id: UUID
    reason: str
    details: str
    status: str
    seller_id: UUID | None
    product_id: UUID | None
    reporter_id: UUID | None
    created_at: datetime


class AdminSellerListOut(AdminPaginatedOut):
    items: list[AdminSellerOut]


class AdminProductListOut(AdminPaginatedOut):
    items: list[AdminProductOut]


class AdminReportListOut(AdminPaginatedOut):
    items: list[AdminReportOut]


class AdminPendingSellerListOut(AdminPaginatedOut):
    items: list[PendingSellerOut]


class AdminAuditLogListOut(AdminPaginatedOut):
    items: list["AdminAuditLogOut"]


class AdminRoleUpdate(BaseModel):
    role: UserRole


class AdminCategoryOut(BaseModel):
    id: UUID
    slug: str
    name_en: str
    name_fr: str
    name_ar: str
    icon: str
    accent_color: str = "#5B6CFF"
    sort_order: int


class AdminCategoryCreate(BaseModel):
    slug: str = Field(min_length=2, max_length=64)
    name_en: str = Field(min_length=1, max_length=80)
    name_fr: str = ""
    name_ar: str = ""
    icon: str = "store"
    accent_color: str = Field(default="#5B6CFF", pattern=r"^#[0-9A-Fa-f]{6}$")
    sort_order: int = 0


class AdminCategoryUpdate(BaseModel):
    name_en: str | None = None
    name_fr: str | None = None
    name_ar: str | None = None
    icon: str | None = None
    accent_color: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    sort_order: int | None = None


class AdminCategoryReorder(BaseModel):
    ordered_ids: list[UUID] = Field(min_length=1, max_length=100)


class AdminReportUpdate(BaseModel):
    status: str = Field(pattern=r"^(open|reviewing|resolved|dismissed)$")
    note: str = Field(default="", max_length=500)


class AdminProductModeration(BaseModel):
    is_hidden: bool | None = None
    is_featured: bool | None = None
    is_paused: bool | None = None
    is_available: bool | None = None


class AdminAnnouncement(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    body: str = Field(min_length=1, max_length=2000)
    audience: str = Field(default="all", pattern=r"^(all|buyers|sellers|premium)$")


class AdminAnnouncementResult(BaseModel):
    sent: int
    audience: str


class AdminAuditLogOut(BaseModel):
    id: UUID
    actor_id: UUID
    action: str
    target_type: str
    target_id: str
    ip_address: str
    success: bool
    previous_value: dict | None
    new_value: dict | None
    metadata: dict
    created_at: datetime

    model_config = {"from_attributes": True}


class AdminSessionOut(BaseModel):
    id: UUID
    device_name: str
    ip_address: str
    user_agent: str
    created_at: datetime
    last_seen_at: datetime | None
    revoked: bool


class AdminAnalyticsOut(BaseModel):
    user_growth: list[dict]
    business_growth: list[dict]
    popular_categories: list[dict]
    daily_active_users: int
    monthly_active_users: int
    geographic_distribution: list[dict]
    search_events_7d: int


class StaffMeOut(BaseModel):
    id: UUID
    email: str
    display_name: str
    role: str
    role_label: str
    permissions: list[str]


# ── Helpers ───────────────────────────────────────────────────────────────────


def _staff_me(user: User) -> StaffMeOut:
    from app.services.admin_permissions import PERMISSIONS

    perms = [key for key, roles in PERMISSIONS.items() if user.role in roles]
    return StaffMeOut(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        role=user.role.value,
        role_label=role_label(user.role),
        permissions=sorted(perms),
    )


async def _count(session: AsyncSession, stmt) -> int:
    return int((await session.scalar(stmt)) or 0)


async def _paginate(
    session: AsyncSession,
    stmt,
    count_stmt,
    *,
    limit: int,
    offset: int,
    order_by,
) -> tuple[list, int]:
    total = await _count(session, count_stmt)
    result = await session.execute(stmt.order_by(order_by).limit(limit).offset(offset))
    return list(result.scalars().all()), total


# ── Auth / identity ─────────────────────────────────────────────────────────


@router.get("/me", response_model=StaffMeOut)
async def admin_me(user: User = Depends(require_staff)) -> StaffMeOut:
    return _staff_me(user)


# ── Dashboard ───────────────────────────────────────────────────────────────


@router.get("/dashboard", response_model=AdminDashboardOut)
async def admin_dashboard(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> AdminDashboardOut:
    assert_permission(user.role, "dashboard.view")
    now = datetime.now(UTC)

    counts = await fetch_dashboard_counts(session, now=now)
    user_growth = await fetch_daily_growth(session, model=User, now=now)
    listing_growth = await fetch_daily_growth(session, model=Product, now=now)

    recent_reports = (
        await session.execute(
            select(Report).order_by(Report.created_at.desc()).limit(5)
        )
    ).scalars().all()
    recent_products = (
        await session.execute(
            select(Product).order_by(Product.created_at.desc()).limit(5)
        )
    ).scalars().all()
    recent_audit = (
        await session.execute(
            select(AdminAuditLog).order_by(AdminAuditLog.created_at.desc()).limit(5)
        )
    ).scalars().all()

    recent_activity = []
    for r in recent_reports:
        recent_activity.append(
            {"type": "report", "id": str(r.id), "at": r.created_at.isoformat(), "label": r.reason}
        )
    for p in recent_products:
        recent_activity.append(
            {"type": "listing", "id": str(p.id), "at": p.created_at.isoformat(), "label": p.name}
        )
    for a in recent_audit:
        recent_activity.append(
            {"type": "audit", "id": str(a.id), "at": a.created_at.isoformat(), "label": a.action}
        )
    recent_activity.sort(key=lambda x: x["at"], reverse=True)
    recent_activity = recent_activity[:10]

    db_ok = True
    try:
        await session.execute(select(func.count(User.id)).limit(1))
    except Exception:
        db_ok = False

    return AdminDashboardOut(
        total_users=counts["total_users"],
        active_users=counts["active_users"],
        new_users_7d=counts["new_users_7d"],
        total_businesses=counts["total_businesses"],
        verified_businesses=counts["verified_businesses"],
        pending_verifications=counts["pending_verifications"],
        total_listings=counts["total_listings"],
        featured_listings=counts["featured_listings"],
        total_categories=counts["total_categories"],
        total_reviews=counts["total_reviews"],
        open_reports=counts["open_reports"],
        premium_subscribers=counts["premium_subscribers"],
        user_growth_30d=user_growth,
        listing_growth_30d=listing_growth,
        recent_activity=recent_activity,
        system_status={
            "database": "ok" if db_ok else "error",
            "api": "ok",
            "storage": "ok",
            "background_jobs": "scheduled_on_startup",
        },
    )


# ── Users ───────────────────────────────────────────────────────────────────


@router.get("/users", response_model=AdminUserListOut)
async def admin_list_users(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    q: str | None = Query(default=None, max_length=120),
    status_filter: UserStatus | None = Query(default=None, alias="status"),
    role_filter: UserRole | None = Query(default=None, alias="role"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminUserListOut:
    assert_permission(user.role, "users.view")
    stmt = select(User)
    count_stmt = select(func.count(User.id))
    if q:
        pattern = f"%{q.strip().lower()}%"
        filt = or_(func.lower(User.email).like(pattern), func.lower(User.display_name).like(pattern))
        stmt = stmt.where(filt)
        count_stmt = count_stmt.where(filt)
    if status_filter:
        stmt = stmt.where(User.status == status_filter)
        count_stmt = count_stmt.where(User.status == status_filter)
    if role_filter:
        stmt = stmt.where(User.role == role_filter)
        count_stmt = count_stmt.where(User.role == role_filter)
    total = await _count(session, count_stmt)
    result = await session.execute(stmt.order_by(User.created_at.desc()).limit(limit).offset(offset))
    items = [
        AdminUserOut(
            id=u.id,
            email=u.email,
            display_name=u.display_name,
            account_type=u.account_type.value,
            role=u.role,
            status=u.status,
            is_premium=u.is_premium,
            created_at=u.created_at,
        )
        for u in result.scalars().all()
    ]
    return AdminUserListOut(items=items, total=total, offset=offset, limit=limit)


@router.get("/users/{user_id}", response_model=AdminUserDetailOut)
async def admin_get_user(
    user_id: UUID,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> AdminUserDetailOut:
    assert_permission(user.role, "users.view")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    return AdminUserDetailOut(
        id=target.id,
        email=target.email,
        display_name=target.display_name,
        account_type=target.account_type.value,
        role=target.role,
        status=target.status,
        is_premium=target.is_premium,
        created_at=target.created_at,
        phone=target.phone,
        last_login_at=target.last_login_at,
        email_verified=target.email_verified_at is not None,
    )


@router.patch(
    "/users/{user_id}/status",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("30/minute")
async def admin_set_status(
    request: Request,
    user_id: UUID,
    status_value: UserStatus = Query(alias="status"),
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "users.write")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    from app.services.account_lifecycle import apply_user_status

    change = await apply_user_status(
        session,
        actor=actor,
        target=target,
        status_value=status_value,
    )
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="set_user_status",
        target_type="user",
        target_id=str(user_id),
        previous_value=change["previous"],
        new_value=change["new"],
        request=request,
    )
    await session.commit()


@router.patch(
    "/users/{user_id}/role",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
)
@limiter.limit("30/minute")
async def admin_set_role(
    request: Request,
    user_id: UUID,
    payload: AdminRoleUpdate,
    actor: User = Depends(require_super_admin),
    session: AsyncSession = Depends(get_db),
) -> Response:
    assert_permission(actor.role, "users.role")
    if payload.role not in {UserRole.ADMIN, UserRole.MODERATOR, UserRole.SUPPORT, UserRole.SUPER_ADMIN, UserRole.BUYER, UserRole.SELLER}:
        raise HTTPException(status_code=400, detail="Invalid staff role assignment")
    if actor.id == user_id and payload.role != actor.role:
        raise HTTPException(status_code=400, detail="Cannot change your own staff role")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    if target.role == UserRole.SUPER_ADMIN and payload.role != UserRole.SUPER_ADMIN:
        remaining = await session.execute(
            select(func.count())
            .select_from(User)
            .where(User.role == UserRole.SUPER_ADMIN, User.status == UserStatus.ACTIVE)
        )
        if (remaining.scalar() or 0) <= 1:
            raise HTTPException(
                status_code=400,
                detail="Cannot demote the last active super admin",
            )
    previous = {"role": target.role.value}
    target.role = payload.role
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="set_user_role",
        target_type="user",
        target_id=str(user_id),
        previous_value=previous,
        new_value={"role": payload.role.value},
        request=request,
    )
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/users/{user_id}/reset-password",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("10/minute")
async def admin_trigger_password_reset(
    request: Request,
    user_id: UUID,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "users.write")
    target = await session.get(User, user_id)
    if target is None or not target.password_hash:
        raise HTTPException(status_code=404, detail="User not found")
    from app.routers.auth import _issue_auth_token, _hash_token

    token = await _issue_auth_token(session, target.id, "password_reset", hours=2)
    await session.commit()
    from app.config import settings

    email_service.send(
        to=target.email,
        subject="Password reset requested by MarGem support",
        text_body=f"Reset your password: {settings.public_app_url.rstrip('/')}/reset-password?token={token}",
    )
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="trigger_password_reset",
        target_type="user",
        target_id=str(user_id),
        request=request,
    )
    await session.commit()


@router.get("/users/{user_id}/sessions", response_model=list[AdminSessionOut])
async def admin_user_sessions(
    user_id: UUID,
    actor: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> list[AdminSessionOut]:
    assert_permission(actor.role, "users.view")
    from app.models import RefreshToken

    result = await session.execute(
        select(RefreshToken)
        .where(RefreshToken.user_id == user_id)
        .order_by(RefreshToken.created_at.desc())
        .limit(50)
    )
    return [
        AdminSessionOut(
            id=t.id,
            device_name=t.device_name or "Device",
            ip_address=t.ip_address,
            user_agent=t.user_agent,
            created_at=t.created_at,
            last_seen_at=t.last_seen_at,
            revoked=t.revoked,
        )
        for t in result.scalars().all()
    ]


@router.delete(
    "/users/{user_id}/sessions",
    status_code=status.HTTP_204_NO_CONTENT,
    response_class=Response,
)
@limiter.limit("10/minute")
async def admin_revoke_user_sessions(
    request: Request,
    user_id: UUID,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> Response:
    assert_permission(actor.role, "users.write")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    await revoke_all_refresh_tokens(session, target.id)
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="revoke_user_sessions",
        target_type="user",
        target_id=str(user_id),
        request=request,
    )
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# ── Businesses ────────────────────────────────────────────────────────────────


@router.get("/sellers", response_model=AdminSellerListOut)
async def admin_list_sellers(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    q: str | None = None,
    verification: VerificationStatus | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminSellerListOut:
    assert_permission(user.role, "businesses.view")
    stmt = select(SellerProfile)
    count_stmt = select(func.count(SellerProfile.id))
    if q:
        pattern = f"%{q.strip().lower()}%"
        filt = func.lower(SellerProfile.business_name).like(pattern)
        stmt = stmt.where(filt)
        count_stmt = count_stmt.where(filt)
    if verification:
        stmt = stmt.where(SellerProfile.verification_status == verification)
        count_stmt = count_stmt.where(SellerProfile.verification_status == verification)
    sellers, total = await _paginate(
        session,
        stmt,
        count_stmt,
        limit=limit,
        offset=offset,
        order_by=SellerProfile.created_at.desc(),
    )
    return AdminSellerListOut(
        items=[
            AdminSellerOut(
                id=s.id,
                business_name=s.business_name,
                city=s.city,
                verification_status=s.verification_status.value,
                is_active=s.is_active,
                is_premium=s.is_premium,
                user_id=s.user_id,
                created_at=s.created_at,
            )
            for s in sellers
        ],
        total=total,
        offset=offset,
        limit=limit,
    )


@router.get("/sellers/pending", response_model=AdminPendingSellerListOut)
async def admin_pending_sellers(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminPendingSellerListOut:
    assert_permission(user.role, "businesses.view")
    stmt = select(SellerProfile).where(
        SellerProfile.verification_status == VerificationStatus.PENDING
    )
    count_stmt = select(func.count(SellerProfile.id)).where(
        SellerProfile.verification_status == VerificationStatus.PENDING
    )
    sellers, total = await _paginate(
        session,
        stmt,
        count_stmt,
        limit=limit,
        offset=offset,
        order_by=SellerProfile.created_at.asc(),
    )
    return AdminPendingSellerListOut(
        items=[
            PendingSellerOut(
                id=s.id,
                business_name=s.business_name,
                city=s.city,
                phone=s.phone,
                user_id=s.user_id,
            )
            for s in sellers
        ],
        total=total,
        offset=offset,
        limit=limit,
    )


@router.post(
    "/sellers/{seller_id}/verify",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("30/minute")
async def admin_verify_seller(
    request: Request,
    seller_id: UUID,
    approve: bool = True,
    actor: User = Depends(require_moderator),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "businesses.moderate")
    from app.routers.seller_ops import notify_user

    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller not found")
    previous = {"verification_status": seller.verification_status.value}
    seller.verification_status = VerificationStatus.VERIFIED if approve else VerificationStatus.REJECTED
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="verify_seller" if approve else "reject_seller",
        target_type="seller",
        target_id=str(seller_id),
        previous_value=previous,
        new_value={"verification_status": seller.verification_status.value},
        request=request,
    )
    await notify_user(
        session,
        user_id=seller.user_id,
        title="Verification update",
        body="Your business was verified" if approve else "Verification was rejected",
        kind="verification",
        data={"seller_id": str(seller_id)},
    )
    await session.commit()


@router.patch(
    "/sellers/{seller_id}/active",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("30/minute")
async def admin_set_seller_active(
    request: Request,
    seller_id: UUID,
    active: bool = True,
    actor: User = Depends(require_moderator),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "businesses.moderate")
    seller = await session.get(SellerProfile, seller_id)
    if seller is None:
        raise HTTPException(status_code=404, detail="Seller not found")
    previous = {"is_active": seller.is_active}
    seller.is_active = active
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="set_seller_active",
        target_type="seller",
        target_id=str(seller_id),
        previous_value=previous,
        new_value={"is_active": active},
        request=request,
    )
    await session.commit()


# ── Listings ────────────────────────────────────────────────────────────────


@router.get("/products", response_model=AdminProductListOut)
async def admin_list_products(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    q: str | None = None,
    hidden: bool | None = None,
    featured: bool | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminProductListOut:
    assert_permission(user.role, "listings.view")
    stmt = select(Product)
    count_stmt = select(func.count(Product.id))
    if q:
        filt = func.lower(Product.name).like(f"%{q.strip().lower()}%")
        stmt = stmt.where(filt)
        count_stmt = count_stmt.where(filt)
    if hidden is not None:
        stmt = stmt.where(Product.is_hidden.is_(hidden))
        count_stmt = count_stmt.where(Product.is_hidden.is_(hidden))
    if featured is not None:
        stmt = stmt.where(Product.is_featured.is_(featured))
        count_stmt = count_stmt.where(Product.is_featured.is_(featured))
    products, total = await _paginate(
        session,
        stmt,
        count_stmt,
        limit=limit,
        offset=offset,
        order_by=Product.created_at.desc(),
    )
    return AdminProductListOut(
        items=[
            AdminProductOut(
                id=p.id,
                name=p.name,
                seller_id=p.seller_id,
                category_slug=p.category_slug,
                is_hidden=p.is_hidden,
                is_featured=p.is_featured,
                is_paused=p.is_paused,
                is_available=p.is_available,
                created_at=p.created_at,
            )
            for p in products
        ],
        total=total,
        offset=offset,
        limit=limit,
    )


@router.patch("/products/{product_id}", response_model=AdminProductOut)
@limiter.limit("60/minute")
async def admin_moderate_product(
    request: Request,
    product_id: UUID,
    payload: AdminProductModeration,
    actor: User = Depends(require_moderator),
    session: AsyncSession = Depends(get_db),
) -> AdminProductOut:
    assert_permission(actor.role, "listings.moderate")
    product = await session.get(Product, product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    previous = {
        "is_hidden": product.is_hidden,
        "is_featured": product.is_featured,
        "is_paused": product.is_paused,
        "is_available": product.is_available,
    }
    if payload.is_hidden is not None:
        product.is_hidden = payload.is_hidden
    if payload.is_featured is not None:
        product.is_featured = payload.is_featured
    if payload.is_paused is not None:
        product.is_paused = payload.is_paused
    if payload.is_available is not None:
        product.is_available = payload.is_available
    new_value = {
        "is_hidden": product.is_hidden,
        "is_featured": product.is_featured,
        "is_paused": product.is_paused,
        "is_available": product.is_available,
    }
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="moderate_product",
        target_type="product",
        target_id=str(product_id),
        previous_value=previous,
        new_value=new_value,
        request=request,
    )
    await session.commit()
    await session.refresh(product)
    return AdminProductOut(
        id=product.id,
        name=product.name,
        seller_id=product.seller_id,
        category_slug=product.category_slug,
        is_hidden=product.is_hidden,
        is_featured=product.is_featured,
        is_paused=product.is_paused,
        is_available=product.is_available,
        created_at=product.created_at,
    )


# ── Reports ─────────────────────────────────────────────────────────────────


@router.get("/reports", response_model=AdminReportListOut)
async def admin_list_reports(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    status_filter: str | None = Query(default="open", alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminReportListOut:
    assert_permission(user.role, "reports.view")
    stmt = select(Report)
    count_stmt = select(func.count(Report.id))
    if status_filter and status_filter != "all":
        stmt = stmt.where(Report.status == status_filter)
        count_stmt = count_stmt.where(Report.status == status_filter)
    reports, total = await _paginate(
        session,
        stmt,
        count_stmt,
        limit=limit,
        offset=offset,
        order_by=Report.created_at.desc(),
    )
    return AdminReportListOut(
        items=[
            AdminReportOut(
                id=r.id,
                reason=r.reason,
                details=r.details,
                status=r.status,
                seller_id=r.seller_id,
                product_id=r.product_id,
                reporter_id=r.reporter_id,
                created_at=r.created_at,
            )
            for r in reports
        ],
        total=total,
        offset=offset,
        limit=limit,
    )


@router.patch("/reports/{report_id}", response_model=AdminReportOut)
@limiter.limit("60/minute")
async def admin_update_report(
    request: Request,
    report_id: UUID,
    payload: AdminReportUpdate,
    actor: User = Depends(require_moderator),
    session: AsyncSession = Depends(get_db),
) -> AdminReportOut:
    assert_permission(actor.role, "reports.moderate")
    report = await session.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    previous = {"status": report.status}
    report.status = payload.status
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="update_report",
        target_type="report",
        target_id=str(report_id),
        previous_value=previous,
        new_value={"status": payload.status, "note": payload.note},
        request=request,
    )
    await session.commit()
    await session.refresh(report)
    return AdminReportOut(
        id=report.id,
        reason=report.reason,
        details=report.details,
        status=report.status,
        seller_id=report.seller_id,
        product_id=report.product_id,
        reporter_id=report.reporter_id,
        created_at=report.created_at,
    )


# ── Categories ──────────────────────────────────────────────────────────────


@router.get("/categories", response_model=list[AdminCategoryOut])
async def admin_list_categories(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> list[AdminCategoryOut]:
    assert_permission(user.role, "categories.view")
    result = await session.execute(select(Category).order_by(Category.sort_order.asc(), Category.name_en.asc()))
    return [
        AdminCategoryOut(
            id=c.id,
            slug=c.slug,
            name_en=c.name_en,
            name_fr=c.name_fr,
            name_ar=c.name_ar,
            icon=c.icon,
            accent_color=c.accent_color,
            sort_order=c.sort_order,
        )
        for c in result.scalars().all()
    ]


@router.post("/categories", response_model=AdminCategoryOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def admin_create_category(
    request: Request,
    payload: AdminCategoryCreate,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> AdminCategoryOut:
    assert_permission(actor.role, "categories.write")
    existing = await session.execute(select(Category).where(Category.slug == payload.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Category slug already exists")
    category = Category(
        id=uuid4(),
        slug=payload.slug,
        name_en=payload.name_en,
        name_fr=payload.name_fr,
        name_ar=payload.name_ar,
        icon=payload.icon,
        accent_color=payload.accent_color,
        sort_order=payload.sort_order,
    )
    session.add(category)
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="create_category",
        target_type="category",
        target_id=str(category.id),
        new_value={"slug": payload.slug},
        request=request,
    )
    await session.commit()
    await session.refresh(category)
    return AdminCategoryOut(
        id=category.id,
        slug=category.slug,
        name_en=category.name_en,
        name_fr=category.name_fr,
        name_ar=category.name_ar,
        icon=category.icon,
        accent_color=category.accent_color,
        sort_order=category.sort_order,
    )


@router.patch("/categories/{category_id}", response_model=AdminCategoryOut)
@limiter.limit("30/minute")
async def admin_update_category(
    request: Request,
    category_id: UUID,
    payload: AdminCategoryUpdate,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> AdminCategoryOut:
    assert_permission(actor.role, "categories.write")
    category = await session.get(Category, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    previous = {
        "name_en": category.name_en,
        "icon": category.icon,
        "sort_order": category.sort_order,
    }
    if payload.name_en is not None:
        category.name_en = payload.name_en
    if payload.name_fr is not None:
        category.name_fr = payload.name_fr
    if payload.name_ar is not None:
        category.name_ar = payload.name_ar
    if payload.icon is not None:
        category.icon = payload.icon
    if payload.accent_color is not None:
        category.accent_color = payload.accent_color
    if payload.sort_order is not None:
        category.sort_order = payload.sort_order
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="update_category",
        target_type="category",
        target_id=str(category_id),
        previous_value=previous,
        new_value=payload.model_dump(exclude_unset=True),
        request=request,
    )
    await session.commit()
    await session.refresh(category)
    return AdminCategoryOut(
        id=category.id,
        slug=category.slug,
        name_en=category.name_en,
        name_fr=category.name_fr,
        name_ar=category.name_ar,
        icon=category.icon,
        accent_color=category.accent_color,
        sort_order=category.sort_order,
    )


@router.post(
    "/categories/reorder",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("30/minute")
async def admin_reorder_categories(
    request: Request,
    payload: AdminCategoryReorder,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "categories.write")
    for index, category_id in enumerate(payload.ordered_ids):
        category = await session.get(Category, category_id)
        if category:
            category.sort_order = index
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="reorder_categories",
        target_type="category",
        target_id="bulk",
        new_value={"count": len(payload.ordered_ids)},
        request=request,
    )
    await session.commit()


# ── Premium (delegate to existing grant logic) ────────────────────────────────


@router.post("/users/{user_id}/premium", response_model=SubscriptionOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def admin_grant_premium(
    request: Request,
    user_id: UUID,
    payload: AdminPremiumGrant,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    assert_permission(admin.role, "premium.write")
    return await grant_premium_to_user(
        session,
        admin=admin,
        user_id=user_id,
        plan_code=payload.plan_code,
        days=payload.days,
        request=request,
    )


@router.delete(
    "/users/{user_id}/premium",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
)
@limiter.limit("30/minute")
async def admin_revoke_premium(
    request: Request,
    user_id: UUID,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    assert_permission(actor.role, "premium.write")
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    previous = {"is_premium": target.is_premium}
    target.is_premium = False
    target.premium_until = None
    subs = await session.execute(
        select(Subscription).where(
            Subscription.user_id == target.id,
            Subscription.status == SubscriptionStatus.ACTIVE,
        )
    )
    for sub in subs.scalars().all():
        sub.status = SubscriptionStatus.CANCELED
        if sub.stripe_subscription_id and settings.stripe_enabled:
            import stripe

            stripe.api_key = settings.stripe_secret_key
            try:
                stripe.Subscription.delete(sub.stripe_subscription_id)
            except stripe.error.StripeError:
                pass
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == target.id))
    ).scalar_one_or_none()
    if seller:
        seller.is_premium = False
    from app.services.subscription_plans import assign_basic_plan

    await assign_basic_plan(session, target, provider="admin_revoke", notify=False)
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="revoke_premium",
        target_type="user",
        target_id=str(user_id),
        previous_value=previous,
        new_value={"is_premium": False},
        request=request,
    )
    await session.commit()


@router.post("/users/{user_id}/premium/sync-stripe", response_model=SubscriptionOut)
@limiter.limit("10/minute")
async def admin_sync_stripe_subscription(
    request: Request,
    user_id: UUID,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> SubscriptionOut:
    """Reconcile a user's Stripe subscription with the local database."""
    assert_permission(actor.role, "premium.write")
    from app.services.stripe_billing import require_stripe_configured, reconcile_stripe_subscriptions

    require_stripe_configured()
    target = await session.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")
    await reconcile_stripe_subscriptions(session)
    result = await session.execute(
        select(Subscription)
        .options(selectinload(Subscription.plan))
        .where(Subscription.user_id == user_id)
        .order_by(Subscription.created_at.desc())
        .limit(1)
    )
    subscription = result.scalar_one_or_none()
    if subscription is None:
        raise HTTPException(status_code=404, detail="No subscription found for user")
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="sync_stripe_subscription",
        target_type="user",
        target_id=str(user_id),
        request=request,
    )
    await session.commit()
    return SubscriptionOut.from_subscription(subscription)


# ── Analytics ───────────────────────────────────────────────────────────────


@router.get("/analytics", response_model=AdminAnalyticsOut)
async def admin_analytics(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> AdminAnalyticsOut:
    assert_permission(user.role, "analytics.view")
    now = datetime.now(UTC)
    day_ago = now - timedelta(days=1)
    month_ago = now - timedelta(days=30)

    user_growth = await fetch_monthly_growth(session, model=User, now=now)
    business_growth = await fetch_monthly_growth(session, model=SellerProfile, now=now)

    cat_rows = await session.execute(
        select(Product.category_slug, func.count(Product.id))
        .group_by(Product.category_slug)
        .order_by(func.count(Product.id).desc())
        .limit(10)
    )
    popular_categories = [
        {"slug": slug or "uncategorized", "count": int(count)} for slug, count in cat_rows.all()
    ]

    dau = await _count(
        session, select(func.count(User.id)).where(User.last_login_at >= day_ago)
    )
    mau = await _count(
        session, select(func.count(User.id)).where(User.last_login_at >= month_ago)
    )

    geo_rows = await session.execute(
        select(SellerProfile.city, func.count(SellerProfile.id))
        .group_by(SellerProfile.city)
        .order_by(func.count(SellerProfile.id).desc())
        .limit(15)
    )
    geographic_distribution = [
        {"city": city, "count": int(count)} for city, count in geo_rows.all()
    ]

    search_events = await _count(
        session, select(func.count(ContactEvent.id)).where(ContactEvent.created_at >= now - timedelta(days=7))
    )

    return AdminAnalyticsOut(
        user_growth=user_growth,
        business_growth=business_growth,
        popular_categories=popular_categories,
        daily_active_users=dau,
        monthly_active_users=mau,
        geographic_distribution=geographic_distribution,
        search_events_7d=search_events,
    )


# ── Notifications (architecture) ─────────────────────────────────────────────


@router.post("/announcements", response_model=AdminAnnouncementResult, status_code=status.HTTP_201_CREATED)
@limiter.limit("10/minute")
async def admin_send_announcement(
    request: Request,
    payload: AdminAnnouncement,
    actor: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> AdminAnnouncementResult:
    """Deliver an in-app announcement to the selected audience."""
    assert_permission(actor.role, "notifications.send")
    from app.services.admin_announcements import send_platform_announcement
    from app.services.text_sanitizer import sanitize_free_text

    title = sanitize_free_text(payload.title, max_length=120)
    body = sanitize_free_text(payload.body, max_length=2000)
    if not title or not body:
        raise HTTPException(status_code=400, detail="Title and message are required")

    sent = await send_platform_announcement(
        session,
        title=title,
        body=body,
        audience=payload.audience,
    )
    await record_admin_action(
        session,
        actor_id=actor.id,
        action="send_announcement",
        target_type="announcement",
        metadata={"audience": payload.audience, "sent": sent},
        request=request,
    )
    await session.commit()
    return AdminAnnouncementResult(sent=sent, audience=payload.audience)


# ── Audit logs ──────────────────────────────────────────────────────────────


@router.get("/audit-logs", response_model=AdminAuditLogListOut)
async def admin_audit_logs(
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
    action: str | None = None,
    actor_id: UUID | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> AdminAuditLogListOut:
    assert_permission(user.role, "audit.view")
    stmt = select(AdminAuditLog)
    count_stmt = select(func.count(AdminAuditLog.id))
    if action:
        stmt = stmt.where(AdminAuditLog.action == action)
        count_stmt = count_stmt.where(AdminAuditLog.action == action)
    if actor_id:
        stmt = stmt.where(AdminAuditLog.actor_id == actor_id)
        count_stmt = count_stmt.where(AdminAuditLog.actor_id == actor_id)
    logs, total = await _paginate(
        session,
        stmt,
        count_stmt,
        limit=limit,
        offset=offset,
        order_by=AdminAuditLog.created_at.desc(),
    )
    return AdminAuditLogListOut(
        items=[
            AdminAuditLogOut(
                id=a.id,
                actor_id=a.actor_id,
                action=a.action,
                target_type=a.target_type,
                target_id=a.target_id,
                ip_address=a.ip_address,
                success=a.success,
                previous_value=a.previous_value,
                new_value=a.new_value,
                metadata=a.metadata_ or {},
                created_at=a.created_at,
            )
            for a in logs
        ],
        total=total,
        offset=offset,
        limit=limit,
    )
