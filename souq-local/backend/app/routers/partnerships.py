"""Seller and public partnership endpoints."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.auth import get_current_user, require_seller, require_verified_email
from app.database import get_db
from app.models import Product, SellerProfile, User
from app.models.partnership import (
    CollaborationStatus,
    InventoryMovementType,
    Partnership,
    PartnershipChatMessage,
    PartnershipCollaboration,
    PartnershipCollaborationResponsibility,
    PartnershipInvitation,
    PartnershipInvitationStatus,
    PartnershipListing,
    PartnershipInventoryMovement,
    PartnershipMember,
    PartnershipMemberRole,
    PartnershipRevenueRecord,
    PartnershipRevenueSplit,
    PartnershipStatus,
    PartnershipType,
    RevenueSplitScope,
)
from app.services.notifications import notify_user
from app.services.partnership_audit import log_partnership_action
from app.services.partnership_permissions import PERMISSION_KEYS, has_permission, permissions_out
from app.services.partnership_trust import (
    compute_joint_trust_score,
    is_partnership_verified,
    load_partnership_with_members,
    member_seller_summaries,
    partnership_duration_days,
)

router = APIRouter(prefix="/partnerships", tags=["partnerships"])

DEFAULT_INVITE_EXPIRY_DAYS = 14
MARKETPLACE_SLUGS = {"derb-ghallef", "derb-omar", "9ri3a", ""}


async def _seller_profile(user: User, session: AsyncSession) -> SellerProfile:
    result = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    profile = result.scalar_one_or_none()
    if profile is None:
        raise HTTPException(status_code=404, detail="Seller profile not found")
    return profile


async def _member_or_404(
    session: AsyncSession, partnership_id: UUID, seller_id: UUID
) -> PartnershipMember:
    result = await session.execute(
        select(PartnershipMember).where(
            PartnershipMember.partnership_id == partnership_id,
            PartnershipMember.seller_id == seller_id,
            PartnershipMember.is_active.is_(True),
        )
    )
    member = result.scalar_one_or_none()
    if member is None:
        raise HTTPException(status_code=403, detail="Not a partnership member")
    return member


def _require_perm(member: PartnershipMember, permission: str) -> None:
    if not has_permission(member, permission):
        raise HTTPException(status_code=403, detail=f"Missing permission: {permission}")


class PartnerSummaryOut(BaseModel):
    seller_id: UUID
    business_name: str
    logo_image_url: str = ""
    average_rating: float = 0.0
    review_count: int = 0
    verification_status: str = "unverified"
    role: str = "partner"
    trust_score: float = 0.0


class PartnershipTrustOut(BaseModel):
    is_verified: bool
    successful_collaborations: int
    duration_days: int
    joint_trust_score: float
    combined_rating: float


class PartnershipOut(BaseModel):
    id: UUID
    name: str
    description: str
    partnership_type: PartnershipType
    marketplace_slug: str
    category_slugs: list[str]
    status: PartnershipStatus
    start_date: datetime
    end_date: datetime | None
    is_verified: bool
    successful_collaborations: int
    members: list[PartnerSummaryOut] = Field(default_factory=list)
    trust: PartnershipTrustOut | None = None
    my_role: str | None = None
    my_permissions: dict[str, bool] | None = None

    model_config = {"from_attributes": True}


class PartnershipCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    description: str = ""
    partnership_type: PartnershipType
    marketplace_slug: str = ""
    category_slugs: list[str] = Field(default_factory=list)
    start_date: datetime | None = None
    end_date: datetime | None = None
    requires_admin_approval: bool = False
    default_revenue_splits: list[dict] = Field(default_factory=list)

    @field_validator("marketplace_slug")
    @classmethod
    def validate_marketplace(cls, value: str) -> str:
        if value and value not in MARKETPLACE_SLUGS:
            raise ValueError("Invalid marketplace slug")
        return value


class PartnershipUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)
    description: str | None = None
    category_slugs: list[str] | None = None
    end_date: datetime | None = None
    status: PartnershipStatus | None = None


class InvitationCreate(BaseModel):
    invitee_seller_id: UUID
    invited_role: PartnershipMemberRole = PartnershipMemberRole.PARTNER
    message: str = ""
    terms: dict = Field(default_factory=dict)
    expires_in_days: int = Field(default=DEFAULT_INVITE_EXPIRY_DAYS, ge=1, le=90)


class InvitationOut(BaseModel):
    id: UUID
    partnership_id: UUID
    partnership_name: str
    inviter_seller_id: UUID
    inviter_name: str
    invitee_seller_id: UUID
    invitee_name: str
    invited_role: PartnershipMemberRole
    message: str
    terms: dict
    status: PartnershipInvitationStatus
    expires_at: datetime
    created_at: datetime
    invitee_profile: PartnerSummaryOut | None = None

    model_config = {"from_attributes": True}


class MemberRoleUpdate(BaseModel):
    role: PartnershipMemberRole
    permissions: dict[str, bool] = Field(default_factory=dict)


class ListingCreate(BaseModel):
    product_id: UUID
    supplier_seller_id: UUID
    fulfiller_seller_id: UUID
    shared_inventory: bool = False
    shared_pricing: bool = False
    custom_price_mad: float | None = Field(default=None, ge=0)
    shared_stock_quantity: int = Field(default=0, ge=0)


class ListingOut(BaseModel):
    id: UUID
    partnership_id: UUID
    product_id: UUID
    product_name: str = ""
    supplier_seller_id: UUID
    supplier_name: str = ""
    fulfiller_seller_id: UUID
    fulfiller_name: str = ""
    shared_inventory: bool
    shared_pricing: bool
    custom_price_mad: float | None
    shared_stock_quantity: int
    reserved_stock_quantity: int
    is_active: bool

    model_config = {"from_attributes": True}


class InventoryMovementCreate(BaseModel):
    listing_id: UUID | None = None
    product_id: UUID
    movement_type: InventoryMovementType
    quantity: int = Field(ge=1)
    from_seller_id: UUID | None = None
    to_seller_id: UUID | None = None
    note: str = ""


class InventoryMovementOut(BaseModel):
    id: UUID
    movement_type: InventoryMovementType
    product_id: UUID
    quantity: int
    note: str
    actor_seller_id: UUID
    from_seller_id: UUID | None
    to_seller_id: UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}


class CollaborationCreate(BaseModel):
    notes: str = ""
    total_amount_mad: float | None = Field(default=None, ge=0)
    responsibilities: list[dict] = Field(default_factory=list)


class CollaborationOut(BaseModel):
    id: UUID
    reference_code: str
    status: CollaborationStatus
    total_amount_mad: float | None
    notes: str
    responsibilities: list[dict] = Field(default_factory=list)
    created_at: datetime

    model_config = {"from_attributes": True}


class RevenueSplitCreate(BaseModel):
    scope: RevenueSplitScope
    scope_ref_id: UUID | None = None
    splits: list[dict]

    @field_validator("splits")
    @classmethod
    def validate_splits(cls, value: list[dict]) -> list[dict]:
        if not value:
            raise ValueError("At least one split required")
        total = sum(float(s.get("percentage", 0)) for s in value)
        if abs(total - 100.0) > 0.01:
            raise ValueError("Split percentages must sum to 100")
        return value


class RevenueSplitOut(BaseModel):
    id: UUID
    scope: RevenueSplitScope
    scope_ref_id: UUID | None
    splits: list
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatMessageCreate(BaseModel):
    body: str = Field(default="", max_length=4000)
    attachment_url: str = ""
    shared_product_id: UUID | None = None
    shared_collaboration_id: UUID | None = None
    task_title: str = ""


class ChatMessageOut(BaseModel):
    id: UUID
    sender_user_id: UUID
    body: str
    attachment_url: str
    shared_product_id: UUID | None
    shared_collaboration_id: UUID | None
    task_title: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AnalyticsOut(BaseModel):
    total_listings: int
    active_listings: int
    total_collaborations: int
    fulfilled_collaborations: int
    total_shared_stock: int
    reserved_stock: int
    revenue_records_count: int
    total_revenue_mad: float
    chat_messages_count: int


class PublicPartnershipOut(BaseModel):
    id: UUID
    name: str
    is_verified: bool
    partnership_type: PartnershipType
    members: list[PartnerSummaryOut]
    combined_rating: float
    joint_trust_score: float


async def _serialize_partnership(
    session: AsyncSession,
    partnership: Partnership,
    *,
    my_member: PartnershipMember | None = None,
) -> PartnershipOut:
    joint = await compute_joint_trust_score(session, partnership.id)
    verified = await is_partnership_verified(session, partnership)
    duration = await partnership_duration_days(partnership)
    members_out: list[PartnerSummaryOut] = []
    for m in partnership.members:
        if not m.is_active:
            continue
        s = m.seller
        members_out.append(
            PartnerSummaryOut(
                seller_id=s.id,
                business_name=s.business_name,
                logo_image_url=s.logo_image_url,
                average_rating=s.average_rating,
                review_count=s.review_count,
                verification_status=s.verification_status.value,
                role=m.role.value,
                trust_score=round(s.average_rating, 2),
            )
        )
    return PartnershipOut(
        id=partnership.id,
        name=partnership.name,
        description=partnership.description,
        partnership_type=partnership.partnership_type,
        marketplace_slug=partnership.marketplace_slug,
        category_slugs=partnership.category_slugs or [],
        status=partnership.status,
        start_date=partnership.start_date,
        end_date=partnership.end_date,
        is_verified=verified,
        successful_collaborations=partnership.successful_collaborations,
        members=members_out,
        trust=PartnershipTrustOut(
            is_verified=verified,
            successful_collaborations=partnership.successful_collaborations,
            duration_days=duration,
            joint_trust_score=joint,
            combined_rating=joint,
        ),
        my_role=my_member.role.value if my_member else None,
        my_permissions=permissions_out(my_member) if my_member else None,
    )


@router.get("/types")
async def list_partnership_types():
    return [{"value": t.value, "label": t.value.replace("_", " ").title()} for t in PartnershipType]


@router.get("/roles")
async def list_partnership_roles():
    return {
        "roles": [r.value for r in PartnershipMemberRole],
        "permissions": list(PERMISSION_KEYS),
    }


@router.post("", response_model=PartnershipOut, status_code=status.HTTP_201_CREATED)
async def create_partnership(
    payload: PartnershipCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    partnership = Partnership(
        name=payload.name.strip(),
        description=payload.description.strip(),
        partnership_type=payload.partnership_type,
        marketplace_slug=payload.marketplace_slug,
        category_slugs=payload.category_slugs,
        status=PartnershipStatus.PENDING,
        start_date=payload.start_date or datetime.now(UTC),
        end_date=payload.end_date,
        requires_admin_approval=payload.requires_admin_approval,
        created_by_seller_id=seller.id,
    )
    session.add(partnership)
    await session.flush()
    member = PartnershipMember(
        partnership_id=partnership.id,
        seller_id=seller.id,
        user_id=user.id,
        role=PartnershipMemberRole.OWNER,
    )
    session.add(member)
    if payload.default_revenue_splits:
        session.add(
            PartnershipRevenueSplit(
                partnership_id=partnership.id,
                scope=RevenueSplitScope.PARTNERSHIP,
                splits=payload.default_revenue_splits,
                created_by_seller_id=seller.id,
            )
        )
    await log_partnership_action(
        session,
        partnership_id=partnership.id,
        action="partnership.created",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        metadata={"name": partnership.name},
    )
    await session.commit()
    loaded = await load_partnership_with_members(session, partnership.id)
    assert loaded is not None
    return await _serialize_partnership(session, loaded, my_member=member)


@router.get("", response_model=list[PartnershipOut])
async def list_my_partnerships(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    result = await session.execute(
        select(Partnership)
        .join(PartnershipMember, PartnershipMember.partnership_id == Partnership.id)
        .where(
            PartnershipMember.seller_id == seller.id,
            PartnershipMember.is_active.is_(True),
        )
        .options(selectinload(Partnership.members).selectinload(PartnershipMember.seller))
        .order_by(Partnership.created_at.desc())
    )
    partnerships = result.scalars().unique().all()
    out: list[PartnershipOut] = []
    for p in partnerships:
        my_member = next((m for m in p.members if m.seller_id == seller.id and m.is_active), None)
        out.append(await _serialize_partnership(session, p, my_member=my_member))
    return out


@router.get("/{partnership_id}", response_model=PartnershipOut)
async def get_partnership(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    partnership = await load_partnership_with_members(session, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    my_member = await _member_or_404(session, partnership_id, seller.id)
    return await _serialize_partnership(session, partnership, my_member=my_member)


@router.patch("/{partnership_id}", response_model=PartnershipOut)
async def update_partnership(
    partnership_id: UUID,
    payload: PartnershipUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "partnership_settings")
    partnership = await load_partnership_with_members(session, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    if payload.name is not None:
        partnership.name = payload.name.strip()
    if payload.description is not None:
        partnership.description = payload.description.strip()
    if payload.category_slugs is not None:
        partnership.category_slugs = payload.category_slugs
    if payload.end_date is not None:
        partnership.end_date = payload.end_date
    if payload.status is not None:
        if payload.status == PartnershipStatus.ACTIVE and partnership.status == PartnershipStatus.PENDING:
            active_members = sum(1 for m in partnership.members if m.is_active)
            if active_members < 2:
                raise HTTPException(status_code=400, detail="Need at least 2 members to activate")
        partnership.status = payload.status
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="partnership.updated",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        metadata=payload.model_dump(exclude_none=True),
    )
    await session.commit()
    await session.refresh(partnership)
    return await _serialize_partnership(session, partnership, my_member=member)


@router.post("/{partnership_id}/invitations", response_model=InvitationOut, status_code=201)
async def send_invitation(
    partnership_id: UUID,
    payload: InvitationCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "team_management")
    if payload.invitee_seller_id == seller.id:
        raise HTTPException(status_code=400, detail="Cannot invite yourself")
    invitee = await session.get(SellerProfile, payload.invitee_seller_id)
    if invitee is None:
        raise HTTPException(status_code=404, detail="Invitee seller not found")
    existing = await session.execute(
        select(PartnershipMember).where(
            PartnershipMember.partnership_id == partnership_id,
            PartnershipMember.seller_id == payload.invitee_seller_id,
            PartnershipMember.is_active.is_(True),
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Seller is already a member")
    partnership = await session.get(Partnership, partnership_id)
    if partnership is None:
        raise HTTPException(status_code=404, detail="Partnership not found")
    invitation = PartnershipInvitation(
        partnership_id=partnership_id,
        inviter_seller_id=seller.id,
        invitee_seller_id=payload.invitee_seller_id,
        invited_role=payload.invited_role,
        message=payload.message.strip(),
        terms=payload.terms,
        expires_at=datetime.now(UTC) + timedelta(days=payload.expires_in_days),
    )
    session.add(invitation)
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="invitation.sent",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="invitation",
        target_id=str(invitation.id),
    )
    invitee_user = await session.get(User, invitee.user_id)
    if invitee_user:
        await notify_user(
            session,
            user_id=invitee_user.id,
            title="Partnership invitation",
            body=f"{seller.business_name} invited you to join {partnership.name}",
            kind="partnership_invite",
            data={"partnership_id": str(partnership_id), "invitation_id": str(invitation.id)},
        )
    await session.commit()
    await session.refresh(invitation)
    return InvitationOut(
        id=invitation.id,
        partnership_id=partnership_id,
        partnership_name=partnership.name,
        inviter_seller_id=seller.id,
        inviter_name=seller.business_name,
        invitee_seller_id=invitee.id,
        invitee_name=invitee.business_name,
        invited_role=invitation.invited_role,
        message=invitation.message,
        terms=invitation.terms,
        status=invitation.status,
        expires_at=invitation.expires_at,
        created_at=invitation.created_at,
        invitee_profile=PartnerSummaryOut(
            seller_id=invitee.id,
            business_name=invitee.business_name,
            logo_image_url=invitee.logo_image_url,
            average_rating=invitee.average_rating,
            review_count=invitee.review_count,
            verification_status=invitee.verification_status.value,
            trust_score=invitee.average_rating,
        ),
    )


@router.get("/me/invitations", response_model=list[InvitationOut])
async def list_invitations_inbox(
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    now = datetime.now(UTC)
    result = await session.execute(
        select(PartnershipInvitation, Partnership, SellerProfile)
        .join(Partnership, Partnership.id == PartnershipInvitation.partnership_id)
        .join(SellerProfile, SellerProfile.id == PartnershipInvitation.inviter_seller_id)
        .where(
            PartnershipInvitation.invitee_seller_id == seller.id,
            PartnershipInvitation.status == PartnershipInvitationStatus.PENDING,
            PartnershipInvitation.expires_at > now,
        )
        .order_by(PartnershipInvitation.created_at.desc())
    )
    rows = result.all()
    return [
        InvitationOut(
            id=inv.id,
            partnership_id=inv.partnership_id,
            partnership_name=partnership.name,
            inviter_seller_id=inv.inviter_seller_id,
            inviter_name=inviter.business_name,
            invitee_seller_id=inv.invitee_seller_id,
            invitee_name=seller.business_name,
            invited_role=inv.invited_role,
            message=inv.message,
            terms=inv.terms,
            status=inv.status,
            expires_at=inv.expires_at,
            created_at=inv.created_at,
            invitee_profile=PartnerSummaryOut(
                seller_id=seller.id,
                business_name=seller.business_name,
                logo_image_url=seller.logo_image_url,
                average_rating=seller.average_rating,
                review_count=seller.review_count,
                verification_status=seller.verification_status.value,
                trust_score=seller.average_rating,
            ),
        )
        for inv, partnership, inviter in rows
    ]


@router.get("/me/invitations/{invitation_id}/preview")
async def preview_invitation(
    invitation_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    result = await session.execute(
        select(PartnershipInvitation, Partnership)
        .join(Partnership, Partnership.id == PartnershipInvitation.partnership_id)
        .where(PartnershipInvitation.id == invitation_id)
    )
    row = result.one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    inv, partnership = row
    if inv.invitee_seller_id != seller.id:
        raise HTTPException(status_code=403, detail="Not your invitation")
    loaded = await load_partnership_with_members(session, partnership.id)
    assert loaded is not None
    inviter = await session.get(SellerProfile, inv.inviter_seller_id)
    return {
        "invitation": InvitationOut(
            id=inv.id,
            partnership_id=inv.partnership_id,
            partnership_name=partnership.name,
            inviter_seller_id=inv.inviter_seller_id,
            inviter_name=inviter.business_name if inviter else "",
            invitee_seller_id=inv.invitee_seller_id,
            invitee_name=seller.business_name,
            invited_role=inv.invited_role,
            message=inv.message,
            terms=inv.terms,
            status=inv.status,
            expires_at=inv.expires_at,
            created_at=inv.created_at,
        ),
        "partnership": await _serialize_partnership(session, loaded),
        "inviter_profile": PartnerSummaryOut(
            seller_id=inviter.id,
            business_name=inviter.business_name,
            logo_image_url=inviter.logo_image_url,
            average_rating=inviter.average_rating,
            review_count=inviter.review_count,
            verification_status=inviter.verification_status.value,
            trust_score=inviter.average_rating,
        )
        if inviter
        else None,
    }


@router.post("/me/invitations/{invitation_id}/accept", status_code=204)
async def accept_invitation(
    invitation_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    inv = await session.get(PartnershipInvitation, invitation_id)
    if inv is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if inv.invitee_seller_id != seller.id:
        raise HTTPException(status_code=403, detail="Not your invitation")
    if inv.status != PartnershipInvitationStatus.PENDING:
        raise HTTPException(status_code=400, detail="Invitation is not pending")
    if inv.expires_at < datetime.now(UTC):
        inv.status = PartnershipInvitationStatus.EXPIRED
        await session.commit()
        raise HTTPException(status_code=410, detail="Invitation expired")
    inv.status = PartnershipInvitationStatus.ACCEPTED
    inv.responded_at = datetime.now(UTC)
    session.add(
        PartnershipMember(
            partnership_id=inv.partnership_id,
            seller_id=seller.id,
            user_id=user.id,
            role=inv.invited_role,
        )
    )
    partnership = await session.get(Partnership, inv.partnership_id)
    if partnership and partnership.status == PartnershipStatus.PENDING:
        partnership.status = PartnershipStatus.ACTIVE
    await log_partnership_action(
        session,
        partnership_id=inv.partnership_id,
        action="invitation.accepted",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="invitation",
        target_id=str(invitation_id),
    )
    await session.commit()


@router.post("/me/invitations/{invitation_id}/decline", status_code=204)
async def decline_invitation(
    invitation_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    inv = await session.get(PartnershipInvitation, invitation_id)
    if inv is None or inv.invitee_seller_id != seller.id:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if inv.status != PartnershipInvitationStatus.PENDING:
        raise HTTPException(status_code=400, detail="Invitation is not pending")
    inv.status = PartnershipInvitationStatus.DECLINED
    inv.responded_at = datetime.now(UTC)
    await log_partnership_action(
        session,
        partnership_id=inv.partnership_id,
        action="invitation.declined",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="invitation",
        target_id=str(invitation_id),
    )
    await session.commit()


@router.post("/me/invitations/{invitation_id}/cancel", status_code=204)
async def cancel_invitation(
    invitation_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    inv = await session.get(PartnershipInvitation, invitation_id)
    if inv is None:
        raise HTTPException(status_code=404, detail="Invitation not found")
    member = await _member_or_404(session, inv.partnership_id, seller.id)
    _require_perm(member, "team_management")
    if inv.status != PartnershipInvitationStatus.PENDING:
        raise HTTPException(status_code=400, detail="Invitation is not pending")
    inv.status = PartnershipInvitationStatus.CANCELLED
    inv.responded_at = datetime.now(UTC)
    await log_partnership_action(
        session,
        partnership_id=inv.partnership_id,
        action="invitation.cancelled",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="invitation",
        target_id=str(invitation_id),
    )
    await session.commit()


@router.patch("/{partnership_id}/members/{member_seller_id}", status_code=204)
async def update_member_role(
    partnership_id: UUID,
    member_seller_id: UUID,
    payload: MemberRoleUpdate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    actor = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(actor, "team_management")
    target = await _member_or_404(session, partnership_id, member_seller_id)
    if target.role == PartnershipMemberRole.OWNER and payload.role != PartnershipMemberRole.OWNER:
        owners = await session.execute(
            select(func.count())
            .select_from(PartnershipMember)
            .where(
                PartnershipMember.partnership_id == partnership_id,
                PartnershipMember.role == PartnershipMemberRole.OWNER,
                PartnershipMember.is_active.is_(True),
            )
        )
        if owners.scalar_one() <= 1:
            raise HTTPException(status_code=400, detail="Cannot remove the only owner role")
    target.role = payload.role
    target.permissions = payload.permissions
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="member.role_updated",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="member",
        target_id=str(member_seller_id),
        metadata={"role": payload.role.value},
    )
    await session.commit()


@router.delete("/{partnership_id}/members/{member_seller_id}", status_code=204)
async def remove_member(
    partnership_id: UUID,
    member_seller_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    actor = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(actor, "team_management")
    target = await _member_or_404(session, partnership_id, member_seller_id)
    target.is_active = False
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="member.removed",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="member",
        target_id=str(member_seller_id),
    )
    await session.commit()


@router.post("/{partnership_id}/listings", response_model=ListingOut, status_code=201)
async def create_listing(
    partnership_id: UUID,
    payload: ListingCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "product_management")
    product = await session.get(Product, payload.product_id)
    if product is None:
        raise HTTPException(status_code=404, detail="Product not found")
    for sid in (payload.supplier_seller_id, payload.fulfiller_seller_id):
        await _member_or_404(session, partnership_id, sid)
    listing = PartnershipListing(
        partnership_id=partnership_id,
        product_id=payload.product_id,
        supplier_seller_id=payload.supplier_seller_id,
        fulfiller_seller_id=payload.fulfiller_seller_id,
        shared_inventory=payload.shared_inventory,
        shared_pricing=payload.shared_pricing,
        custom_price_mad=payload.custom_price_mad,
        shared_stock_quantity=payload.shared_stock_quantity,
    )
    session.add(listing)
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="listing.created",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="listing",
        target_id=str(payload.product_id),
    )
    await session.commit()
    await session.refresh(listing)
    supplier = await session.get(SellerProfile, listing.supplier_seller_id)
    fulfiller = await session.get(SellerProfile, listing.fulfiller_seller_id)
    return ListingOut(
        id=listing.id,
        partnership_id=listing.partnership_id,
        product_id=listing.product_id,
        product_name=product.name,
        supplier_seller_id=listing.supplier_seller_id,
        supplier_name=supplier.business_name if supplier else "",
        fulfiller_seller_id=listing.fulfiller_seller_id,
        fulfiller_name=fulfiller.business_name if fulfiller else "",
        shared_inventory=listing.shared_inventory,
        shared_pricing=listing.shared_pricing,
        custom_price_mad=listing.custom_price_mad,
        shared_stock_quantity=listing.shared_stock_quantity,
        reserved_stock_quantity=listing.reserved_stock_quantity,
        is_active=listing.is_active,
    )


@router.get("/{partnership_id}/listings", response_model=list[ListingOut])
async def list_listings(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    await _member_or_404(session, partnership_id, seller.id)
    listings_result = await session.execute(
        select(PartnershipListing).where(PartnershipListing.partnership_id == partnership_id)
    )
    listings = listings_result.scalars().all()
    out: list[ListingOut] = []
    for listing in listings:
        product = await session.get(Product, listing.product_id)
        supplier = await session.get(SellerProfile, listing.supplier_seller_id)
        fulfiller = await session.get(SellerProfile, listing.fulfiller_seller_id)
        out.append(
            ListingOut(
                id=listing.id,
                partnership_id=listing.partnership_id,
                product_id=listing.product_id,
                product_name=product.name if product else "",
                supplier_seller_id=listing.supplier_seller_id,
                supplier_name=supplier.business_name if supplier else "",
                fulfiller_seller_id=listing.fulfiller_seller_id,
                fulfiller_name=fulfiller.business_name if fulfiller else "",
                shared_inventory=listing.shared_inventory,
                shared_pricing=listing.shared_pricing,
                custom_price_mad=listing.custom_price_mad,
                shared_stock_quantity=listing.shared_stock_quantity,
                reserved_stock_quantity=listing.reserved_stock_quantity,
                is_active=listing.is_active,
            )
        )
    return out


@router.post("/{partnership_id}/inventory/movements", response_model=InventoryMovementOut, status_code=201)
async def record_inventory_movement(
    partnership_id: UUID,
    payload: InventoryMovementCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "inventory_management")
    listing = None
    if payload.listing_id:
        listing = await session.get(PartnershipListing, payload.listing_id)
        if listing is None or listing.partnership_id != partnership_id:
            raise HTTPException(status_code=404, detail="Listing not found")
    movement = PartnershipInventoryMovement(
        partnership_id=partnership_id,
        listing_id=payload.listing_id,
        product_id=payload.product_id,
        actor_seller_id=seller.id,
        from_seller_id=payload.from_seller_id,
        to_seller_id=payload.to_seller_id,
        movement_type=payload.movement_type,
        quantity=payload.quantity,
        note=payload.note.strip(),
    )
    session.add(movement)
    if listing and listing.shared_inventory:
        if payload.movement_type == InventoryMovementType.RESERVE:
            if listing.shared_stock_quantity - listing.reserved_stock_quantity < payload.quantity:
                raise HTTPException(status_code=400, detail="Insufficient shared stock")
            listing.reserved_stock_quantity += payload.quantity
        elif payload.movement_type == InventoryMovementType.RELEASE:
            listing.reserved_stock_quantity = max(0, listing.reserved_stock_quantity - payload.quantity)
        elif payload.movement_type == InventoryMovementType.SHARE:
            listing.shared_stock_quantity += payload.quantity
        elif payload.movement_type == InventoryMovementType.ADJUST:
            listing.shared_stock_quantity = max(0, listing.shared_stock_quantity + payload.quantity)
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="inventory.movement",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="inventory",
        metadata=payload.model_dump(mode="json"),
    )
    await session.commit()
    await session.refresh(movement)
    return InventoryMovementOut.model_validate(movement)


@router.get("/{partnership_id}/inventory/movements", response_model=list[InventoryMovementOut])
async def list_inventory_movements(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, le=200),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    if not has_permission(member, "inventory_management") and not has_permission(member, "analytics"):
        raise HTTPException(status_code=403, detail="Missing permission")
    result = await session.execute(
        select(PartnershipInventoryMovement)
        .where(PartnershipInventoryMovement.partnership_id == partnership_id)
        .order_by(PartnershipInventoryMovement.created_at.desc())
        .limit(limit)
    )
    return [InventoryMovementOut.model_validate(m) for m in result.scalars().all()]


@router.post("/{partnership_id}/collaborations", response_model=CollaborationOut, status_code=201)
async def create_collaboration(
    partnership_id: UUID,
    payload: CollaborationCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "order_management")
    ref = f"PC-{secrets.token_hex(4).upper()}"
    collab = PartnershipCollaboration(
        partnership_id=partnership_id,
        reference_code=ref,
        customer_user_id=user.id,
        status=CollaborationStatus.INQUIRY,
        total_amount_mad=payload.total_amount_mad,
        notes=payload.notes.strip(),
    )
    session.add(collab)
    await session.flush()
    for resp in payload.responsibilities:
        session.add(
            PartnershipCollaborationResponsibility(
                collaboration_id=collab.id,
                seller_id=UUID(str(resp["seller_id"])),
                responsibility_type=str(resp.get("responsibility_type", "supply")),
                status=str(resp.get("status", "pending")),
                notes=str(resp.get("notes", "")),
            )
        )
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="collaboration.created",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="collaboration",
        target_id=str(collab.id),
    )
    await session.commit()
    await session.refresh(collab)
    resp_result = await session.execute(
        select(PartnershipCollaborationResponsibility).where(
            PartnershipCollaborationResponsibility.collaboration_id == collab.id
        )
    )
    responsibilities = [
        {
            "seller_id": str(r.seller_id),
            "responsibility_type": r.responsibility_type,
            "status": r.status,
            "notes": r.notes,
        }
        for r in resp_result.scalars().all()
    ]
    return CollaborationOut(
        id=collab.id,
        reference_code=collab.reference_code,
        status=collab.status,
        total_amount_mad=collab.total_amount_mad,
        notes=collab.notes,
        responsibilities=responsibilities,
        created_at=collab.created_at,
    )


@router.get("/{partnership_id}/collaborations", response_model=list[CollaborationOut])
async def list_collaborations(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "order_management")
    result = await session.execute(
        select(PartnershipCollaboration)
        .where(PartnershipCollaboration.partnership_id == partnership_id)
        .order_by(PartnershipCollaboration.created_at.desc())
    )
    collabs = result.scalars().all()
    out: list[CollaborationOut] = []
    for collab in collabs:
        resp_result = await session.execute(
            select(PartnershipCollaborationResponsibility).where(
                PartnershipCollaborationResponsibility.collaboration_id == collab.id
            )
        )
        responsibilities = [
            {
                "seller_id": str(r.seller_id),
                "responsibility_type": r.responsibility_type,
                "status": r.status,
                "notes": r.notes,
            }
            for r in resp_result.scalars().all()
        ]
        out.append(
            CollaborationOut(
                id=collab.id,
                reference_code=collab.reference_code,
                status=collab.status,
                total_amount_mad=collab.total_amount_mad,
                notes=collab.notes,
                responsibilities=responsibilities,
                created_at=collab.created_at,
            )
        )
    return out


@router.patch("/{partnership_id}/collaborations/{collaboration_id}/status", status_code=204)
async def update_collaboration_status(
    partnership_id: UUID,
    collaboration_id: UUID,
    new_status: CollaborationStatus,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "order_management")
    collab = await session.get(PartnershipCollaboration, collaboration_id)
    if collab is None or collab.partnership_id != partnership_id:
        raise HTTPException(status_code=404, detail="Collaboration not found")
    collab.status = new_status
    if new_status == CollaborationStatus.FULFILLED:
        partnership = await session.get(Partnership, partnership_id)
        if partnership:
            partnership.successful_collaborations += 1
        if collab.total_amount_mad:
            split_result = await session.execute(
                select(PartnershipRevenueSplit)
                .where(
                    PartnershipRevenueSplit.partnership_id == partnership_id,
                    PartnershipRevenueSplit.scope == RevenueSplitScope.COLLABORATION,
                    PartnershipRevenueSplit.scope_ref_id == collaboration_id,
                )
                .limit(1)
            )
            split = split_result.scalar_one_or_none()
            if split is None:
                split_result = await session.execute(
                    select(PartnershipRevenueSplit)
                    .where(
                        PartnershipRevenueSplit.partnership_id == partnership_id,
                        PartnershipRevenueSplit.scope == RevenueSplitScope.PARTNERSHIP,
                    )
                    .order_by(PartnershipRevenueSplit.created_at.desc())
                    .limit(1)
                )
                split = split_result.scalar_one_or_none()
            if split:
                total = float(collab.total_amount_mad)
                allocations = []
                for entry in split.splits:
                    pct = float(entry.get("percentage", 0))
                    sid = entry.get("seller_id")
                    allocations.append(
                        {
                            "seller_id": str(sid),
                            "percentage": pct,
                            "amount_mad": round(total * pct / 100.0, 2),
                        }
                    )
                session.add(
                    PartnershipRevenueRecord(
                        partnership_id=partnership_id,
                        collaboration_id=collaboration_id,
                        total_amount_mad=total,
                        allocations=allocations,
                    )
                )
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="collaboration.status_updated",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="collaboration",
        target_id=str(collaboration_id),
        metadata={"status": new_status.value},
    )
    await session.commit()


@router.post("/{partnership_id}/revenue-splits", response_model=RevenueSplitOut, status_code=201)
async def create_revenue_split(
    partnership_id: UUID,
    payload: RevenueSplitCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "pricing")
    split = PartnershipRevenueSplit(
        partnership_id=partnership_id,
        scope=payload.scope,
        scope_ref_id=payload.scope_ref_id,
        splits=payload.splits,
        created_by_seller_id=seller.id,
    )
    session.add(split)
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="revenue_split.created",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        metadata=payload.model_dump(mode="json"),
    )
    await session.commit()
    await session.refresh(split)
    return RevenueSplitOut.model_validate(split)


@router.get("/{partnership_id}/revenue-splits", response_model=list[RevenueSplitOut])
async def list_revenue_splits(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "analytics")
    result = await session.execute(
        select(PartnershipRevenueSplit)
        .where(PartnershipRevenueSplit.partnership_id == partnership_id)
        .order_by(PartnershipRevenueSplit.created_at.desc())
    )
    return [RevenueSplitOut.model_validate(s) for s in result.scalars().all()]


@router.get("/{partnership_id}/revenue-records")
async def list_revenue_records(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "analytics")
    result = await session.execute(
        select(PartnershipRevenueRecord)
        .where(PartnershipRevenueRecord.partnership_id == partnership_id)
        .order_by(PartnershipRevenueRecord.created_at.desc())
    )
    return [
        {
            "id": str(r.id),
            "collaboration_id": str(r.collaboration_id) if r.collaboration_id else None,
            "total_amount_mad": float(r.total_amount_mad),
            "allocations": r.allocations,
            "note": r.note,
            "created_at": r.created_at.isoformat(),
        }
        for r in result.scalars().all()
    ]


@router.post("/{partnership_id}/chat/messages", response_model=ChatMessageOut, status_code=201)
async def post_chat_message(
    partnership_id: UUID,
    payload: ChatMessageCreate,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "messaging")
    if not payload.body.strip() and not payload.attachment_url and not payload.task_title:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    msg = PartnershipChatMessage(
        partnership_id=partnership_id,
        sender_user_id=user.id,
        body=payload.body.strip(),
        attachment_url=payload.attachment_url.strip(),
        shared_product_id=payload.shared_product_id,
        shared_collaboration_id=payload.shared_collaboration_id,
        task_title=payload.task_title.strip(),
    )
    session.add(msg)
    await log_partnership_action(
        session,
        partnership_id=partnership_id,
        action="chat.message_sent",
        actor_user_id=user.id,
        actor_seller_id=seller.id,
        target_type="chat",
        target_id=str(msg.id),
    )
    await session.commit()
    await session.refresh(msg)
    return ChatMessageOut.model_validate(msg)


@router.get("/{partnership_id}/chat/messages", response_model=list[ChatMessageOut])
async def list_chat_messages(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=100, le=300),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "messaging")
    result = await session.execute(
        select(PartnershipChatMessage)
        .where(PartnershipChatMessage.partnership_id == partnership_id)
        .order_by(PartnershipChatMessage.created_at.asc())
        .limit(limit)
    )
    return [ChatMessageOut.model_validate(m) for m in result.scalars().all()]


@router.get("/{partnership_id}/analytics", response_model=AnalyticsOut)
async def partnership_analytics(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "analytics")
    listings = await session.execute(
        select(func.count()).select_from(PartnershipListing).where(
            PartnershipListing.partnership_id == partnership_id
        )
    )
    active_listings = await session.execute(
        select(func.count()).select_from(PartnershipListing).where(
            PartnershipListing.partnership_id == partnership_id,
            PartnershipListing.is_active.is_(True),
        )
    )
    collabs = await session.execute(
        select(func.count()).select_from(PartnershipCollaboration).where(
            PartnershipCollaboration.partnership_id == partnership_id
        )
    )
    fulfilled = await session.execute(
        select(func.count()).select_from(PartnershipCollaboration).where(
            PartnershipCollaboration.partnership_id == partnership_id,
            PartnershipCollaboration.status == CollaborationStatus.FULFILLED,
        )
    )
    stock = await session.execute(
        select(
            func.coalesce(func.sum(PartnershipListing.shared_stock_quantity), 0),
            func.coalesce(func.sum(PartnershipListing.reserved_stock_quantity), 0),
        ).where(PartnershipListing.partnership_id == partnership_id)
    )
    stock_row = stock.one()
    revenue_count = await session.execute(
        select(func.count()).select_from(PartnershipRevenueRecord).where(
            PartnershipRevenueRecord.partnership_id == partnership_id
        )
    )
    revenue_sum = await session.execute(
        select(func.coalesce(func.sum(PartnershipRevenueRecord.total_amount_mad), 0)).where(
            PartnershipRevenueRecord.partnership_id == partnership_id
        )
    )
    chat_count = await session.execute(
        select(func.count()).select_from(PartnershipChatMessage).where(
            PartnershipChatMessage.partnership_id == partnership_id
        )
    )
    return AnalyticsOut(
        total_listings=listings.scalar_one(),
        active_listings=active_listings.scalar_one(),
        total_collaborations=collabs.scalar_one(),
        fulfilled_collaborations=fulfilled.scalar_one(),
        total_shared_stock=int(stock_row[0]),
        reserved_stock=int(stock_row[1]),
        revenue_records_count=revenue_count.scalar_one(),
        total_revenue_mad=float(revenue_sum.scalar_one()),
        chat_messages_count=chat_count.scalar_one(),
    )


@router.get("/{partnership_id}/audit-log")
async def partnership_audit_log(
    partnership_id: UUID,
    user: User = Depends(require_seller),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=100, le=500),
):
    seller = await _seller_profile(user, session)
    member = await _member_or_404(session, partnership_id, seller.id)
    _require_perm(member, "partnership_settings")
    from app.models.partnership import PartnershipAuditLog

    result = await session.execute(
        select(PartnershipAuditLog)
        .where(PartnershipAuditLog.partnership_id == partnership_id)
        .order_by(PartnershipAuditLog.created_at.desc())
        .limit(limit)
    )
    return [
        {
            "id": str(e.id),
            "action": e.action,
            "target_type": e.target_type,
            "target_id": e.target_id,
            "metadata": e.metadata_,
            "created_at": e.created_at.isoformat(),
        }
        for e in result.scalars().all()
    ]


@router.get("/public/product/{product_id}", response_model=PublicPartnershipOut | None)
async def public_product_partnership(
    product_id: UUID,
    session: AsyncSession = Depends(get_db),
):
    result = await session.execute(
        select(PartnershipListing, Partnership)
        .join(Partnership, Partnership.id == PartnershipListing.partnership_id)
        .where(
            PartnershipListing.product_id == product_id,
            PartnershipListing.is_active.is_(True),
            Partnership.status == PartnershipStatus.ACTIVE,
        )
        .limit(1)
    )
    row = result.one_or_none()
    if row is None:
        return None
    listing, partnership = row
    loaded = await load_partnership_with_members(session, partnership.id)
    if loaded is None:
        return None
    joint = await compute_joint_trust_score(session, partnership.id)
    verified = await is_partnership_verified(session, partnership)
    members = await member_seller_summaries(loaded)
    return PublicPartnershipOut(
        id=partnership.id,
        name=partnership.name,
        is_verified=verified,
        partnership_type=partnership.partnership_type,
        members=[
            PartnerSummaryOut(
                seller_id=UUID(m["seller_id"]),
                business_name=m["business_name"],
                logo_image_url=m["logo_image_url"],
                average_rating=m["average_rating"],
                review_count=m["review_count"],
                verification_status=m["verification_status"],
                role=m["role"],
                trust_score=m["average_rating"],
            )
            for m in members
        ],
        combined_rating=joint,
        joint_trust_score=joint,
    )


@router.get("/public/{partnership_id}", response_model=PublicPartnershipOut)
async def public_partnership(
    partnership_id: UUID,
    session: AsyncSession = Depends(get_db),
):
    partnership = await load_partnership_with_members(session, partnership_id)
    if partnership is None or partnership.status != PartnershipStatus.ACTIVE:
        raise HTTPException(status_code=404, detail="Partnership not found")
    joint = await compute_joint_trust_score(session, partnership.id)
    verified = await is_partnership_verified(session, partnership)
    members = await member_seller_summaries(partnership)
    return PublicPartnershipOut(
        id=partnership.id,
        name=partnership.name,
        is_verified=verified,
        partnership_type=partnership.partnership_type,
        members=[
            PartnerSummaryOut(
                seller_id=UUID(m["seller_id"]),
                business_name=m["business_name"],
                logo_image_url=m["logo_image_url"],
                average_rating=m["average_rating"],
                review_count=m["review_count"],
                verification_status=m["verification_status"],
                role=m["role"],
                trust_score=m["average_rating"],
            )
            for m in members
        ],
        combined_rating=joint,
        joint_trust_score=joint,
    )
