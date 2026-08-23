"""Business partnership & teaming models."""

from __future__ import annotations

import enum
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models import Base, SellerProfile, User, _enum


class PartnershipType(str, enum.Enum):
    TEMPORARY = "temporary"
    LONG_TERM = "long_term"
    SUPPLIER_RETAILER = "supplier_retailer"
    SERVICE_PROVIDER = "service_provider"
    WHOLESALE = "wholesale"
    MULTI_SHOP = "multi_shop"


class PartnershipStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    ENDED = "ended"


class PartnershipInvitationStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


class PartnershipMemberRole(str, enum.Enum):
    OWNER = "owner"
    PARTNER = "partner"
    MANAGER = "manager"
    INVENTORY_MANAGER = "inventory_manager"
    SALES_MANAGER = "sales_manager"
    CUSTOMER_SUPPORT = "customer_support"


class InventoryMovementType(str, enum.Enum):
    SHARE = "share"
    RESERVE = "reserve"
    RELEASE = "release"
    TRANSFER = "transfer"
    ADJUST = "adjust"


class CollaborationStatus(str, enum.Enum):
    INQUIRY = "inquiry"
    IN_PROGRESS = "in_progress"
    FULFILLED = "fulfilled"
    CANCELLED = "cancelled"


class RevenueSplitScope(str, enum.Enum):
    PARTNERSHIP = "partnership"
    PRODUCT = "product"
    COLLABORATION = "collaboration"


partnership_type_enum = _enum(PartnershipType, "partnertype")
partnership_status_enum = _enum(PartnershipStatus, "partnershipstatus")
partnership_invitation_status_enum = _enum(PartnershipInvitationStatus, "partnershipinvitationstatus")
partnership_member_role_enum = _enum(PartnershipMemberRole, "partnershipmemberrole")
inventory_movement_type_enum = _enum(InventoryMovementType, "inventorymovementtype")
collaboration_status_enum = _enum(CollaborationStatus, "collaborationstatus")
revenue_split_scope_enum = _enum(RevenueSplitScope, "revenuesplitscope")


class Partnership(Base):
    __tablename__ = "partnerships"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    partnership_type: Mapped[PartnershipType] = mapped_column(partnership_type_enum)
    marketplace_slug: Mapped[str] = mapped_column(String(64), default="", index=True)
    category_slugs: Mapped[list] = mapped_column(JSONB, default=list)
    status: Mapped[PartnershipStatus] = mapped_column(
        partnership_status_enum, default=PartnershipStatus.PENDING, index=True
    )
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    end_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    requires_admin_approval: Mapped[bool] = mapped_column(Boolean, default=False)
    admin_approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    admin_approved_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    successful_collaborations: Mapped[int] = mapped_column(Integer, default=0)
    created_by_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    members: Mapped[list["PartnershipMember"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    invitations: Mapped[list["PartnershipInvitation"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    listings: Mapped[list["PartnershipListing"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    inventory_movements: Mapped[list["PartnershipInventoryMovement"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    collaborations: Mapped[list["PartnershipCollaboration"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    revenue_splits: Mapped[list["PartnershipRevenueSplit"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    chat_messages: Mapped[list["PartnershipChatMessage"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )
    audit_logs: Mapped[list["PartnershipAuditLog"]] = relationship(
        back_populates="partnership", cascade="all, delete-orphan"
    )


class PartnershipMember(Base):
    __tablename__ = "partnership_members"
    __table_args__ = (UniqueConstraint("partnership_id", "seller_id", name="uq_partnership_member"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[PartnershipMemberRole] = mapped_column(partnership_member_role_enum)
    permissions: Mapped[dict] = mapped_column(JSONB, default=dict)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    partnership: Mapped[Partnership] = relationship(back_populates="members")
    seller: Mapped[SellerProfile] = relationship()
    user: Mapped[User] = relationship()


class PartnershipInvitation(Base):
    __tablename__ = "partnership_invitations"
    __table_args__ = (
        Index("ix_partnership_invite_invitee", "invitee_seller_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    inviter_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    invitee_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    invited_role: Mapped[PartnershipMemberRole] = mapped_column(
        partnership_member_role_enum, default=PartnershipMemberRole.PARTNER
    )
    message: Mapped[str] = mapped_column(Text, default="")
    terms: Mapped[dict] = mapped_column(JSONB, default=dict)
    status: Mapped[PartnershipInvitationStatus] = mapped_column(
        partnership_invitation_status_enum, default=PartnershipInvitationStatus.PENDING, index=True
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="invitations")
    inviter_seller: Mapped[SellerProfile] = relationship(foreign_keys=[inviter_seller_id])
    invitee_seller: Mapped[SellerProfile] = relationship(foreign_keys=[invitee_seller_id])


class PartnershipListing(Base):
    __tablename__ = "partnership_listings"
    __table_args__ = (UniqueConstraint("partnership_id", "product_id", name="uq_partnership_listing_product"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    supplier_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    fulfiller_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    shared_inventory: Mapped[bool] = mapped_column(Boolean, default=False)
    shared_pricing: Mapped[bool] = mapped_column(Boolean, default=False)
    custom_price_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    shared_stock_quantity: Mapped[int] = mapped_column(Integer, default=0)
    reserved_stock_quantity: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="listings")


class PartnershipInventoryMovement(Base):
    __tablename__ = "partnership_inventory_movements"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    listing_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("partnership_listings.id", ondelete="SET NULL"), nullable=True, index=True
    )
    product_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), index=True)
    actor_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    from_seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True
    )
    to_seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True
    )
    movement_type: Mapped[InventoryMovementType] = mapped_column(inventory_movement_type_enum)
    quantity: Mapped[int] = mapped_column(Integer)
    note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="inventory_movements")


class PartnershipCollaboration(Base):
    """Collaborative customer inquiry / fulfillment record (discovery-platform)."""

    __tablename__ = "partnership_collaborations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    reference_code: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    customer_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    status: Mapped[CollaborationStatus] = mapped_column(
        collaboration_status_enum, default=CollaborationStatus.INQUIRY, index=True
    )
    total_amount_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    notes: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    partnership: Mapped[Partnership] = relationship(back_populates="collaborations")
    responsibilities: Mapped[list["PartnershipCollaborationResponsibility"]] = relationship(
        back_populates="collaboration", cascade="all, delete-orphan"
    )


class PartnershipCollaborationResponsibility(Base):
    __tablename__ = "partnership_collaboration_responsibilities"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    collaboration_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnership_collaborations.id", ondelete="CASCADE"), index=True
    )
    seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True
    )
    responsibility_type: Mapped[str] = mapped_column(String(40))  # supply|fulfillment|installation|delivery|support
    status: Mapped[str] = mapped_column(String(32), default="pending")
    notes: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    collaboration: Mapped[PartnershipCollaboration] = relationship(back_populates="responsibilities")


class PartnershipRevenueSplit(Base):
    __tablename__ = "partnership_revenue_splits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    scope: Mapped[RevenueSplitScope] = mapped_column(revenue_split_scope_enum, index=True)
    scope_ref_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True, index=True)
    splits: Mapped[list] = mapped_column(JSONB, default=list)  # [{seller_id, percentage}]
    created_by_seller_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE")
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="revenue_splits")


class PartnershipRevenueRecord(Base):
    """Transparent financial record for a collaboration revenue split."""

    __tablename__ = "partnership_revenue_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    collaboration_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("partnership_collaborations.id", ondelete="SET NULL"), nullable=True, index=True
    )
    total_amount_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    allocations: Mapped[list] = mapped_column(JSONB, default=list)  # [{seller_id, amount_mad, percentage}]
    note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class PartnershipChatMessage(Base):
    __tablename__ = "partnership_chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    sender_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    body: Mapped[str] = mapped_column(Text, default="")
    attachment_url: Mapped[str] = mapped_column(String(512), default="")
    shared_product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    shared_collaboration_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("partnership_collaborations.id", ondelete="SET NULL"), nullable=True
    )
    task_title: Mapped[str] = mapped_column(String(160), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="chat_messages")


class PartnershipAuditLog(Base):
    __tablename__ = "partnership_audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    partnership_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("partnerships.id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    actor_seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True
    )
    action: Mapped[str] = mapped_column(String(80), index=True)
    target_type: Mapped[str] = mapped_column(String(40), default="")
    target_id: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    partnership: Mapped[Partnership] = relationship(back_populates="audit_logs")
