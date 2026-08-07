"""Marketplace-scoped community chat — separate from city (Casablanca) community."""

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
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models import Base, User, _enum


class MarketplacePostType(str, enum.Enum):
    GENERAL = "general"
    QUESTION = "question"
    SELLER_RECOMMENDATION = "seller_recommendation"
    DEAL = "deal"
    ANNOUNCEMENT = "announcement"
    SCAM_REPORT = "scam_report"


class MarketplaceMessageStatus(str, enum.Enum):
    VISIBLE = "visible"
    PENDING_MODERATION = "pending_moderation"
    HIDDEN = "hidden"
    DELETED = "deleted"


class MarketplaceReportStatus(str, enum.Enum):
    OPEN = "open"
    REVIEWED = "reviewed"
    DISMISSED = "dismissed"
    ACTIONED = "actioned"


marketplace_post_type_enum = _enum(MarketplacePostType, "marketplaceposttype")
marketplace_message_status_enum = _enum(MarketplaceMessageStatus, "marketplacemessagestatus")
marketplace_report_status_enum = _enum(MarketplaceReportStatus, "marketplacereportstatus")

MARKETPLACE_CHANNEL_SEEDS: dict[str, list[tuple[str, str, str, MarketplacePostType]]] = {
    "derb-ghallef": [
        ("general", "General", "Open discussion for Derb Ghallef", MarketplacePostType.GENERAL),
        ("phones", "Phones", "Phones, accessories, and mobile deals", MarketplacePostType.DEAL),
        ("gaming", "Gaming", "Consoles, games, and gaming gear", MarketplacePostType.DEAL),
        ("deals", "Deals", "Share deals and price drops", MarketplacePostType.DEAL),
        ("repairs", "Repairs", "Repair tips and trusted technicians", MarketplacePostType.SELLER_RECOMMENDATION),
    ],
    "derb-omar": [
        ("hardware", "Hardware", "Tools and hardware discussion", MarketplacePostType.GENERAL),
        ("construction", "Construction", "Building materials and construction", MarketplacePostType.GENERAL),
        ("wholesale", "Wholesale", "Bulk and wholesale offers", MarketplacePostType.DEAL),
    ],
    "9ti3a": [
        ("toyota", "Toyota", "Toyota parts and mechanics", MarketplacePostType.GENERAL),
        ("bmw", "BMW", "BMW parts and mechanics", MarketplacePostType.GENERAL),
        ("mercedes", "Mercedes", "Mercedes parts and mechanics", MarketplacePostType.GENERAL),
    ],
}


class MarketplaceCommunityChannel(Base):
    __tablename__ = "marketplace_community_channels"
    __table_args__ = (
        UniqueConstraint("marketplace_id", "slug", name="uq_marketplace_community_channel_slug"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    marketplace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="CASCADE"), index=True
    )
    slug: Mapped[str] = mapped_column(String(80), index=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    default_post_type: Mapped[MarketplacePostType] = mapped_column(
        marketplace_post_type_enum, default=MarketplacePostType.GENERAL
    )
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    messages: Mapped[list["MarketplaceCommunityMessage"]] = relationship(
        back_populates="channel", cascade="all, delete-orphan"
    )


class MarketplaceCommunityMembership(Base):
    __tablename__ = "marketplace_community_memberships"
    __table_args__ = (
        UniqueConstraint("user_id", "marketplace_id", name="uq_marketplace_community_membership"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    marketplace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="CASCADE"), index=True
    )
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class MarketplaceCommunityMessage(Base):
    __tablename__ = "marketplace_community_messages"
    __table_args__ = (
        Index("ix_mp_community_messages_channel_created", "channel_id", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplace_community_channels.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    body: Mapped[str] = mapped_column(Text, default="")
    post_type: Mapped[MarketplacePostType] = mapped_column(
        marketplace_post_type_enum, default=MarketplacePostType.GENERAL, index=True
    )
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("marketplace_community_messages.id", ondelete="SET NULL"), nullable=True, index=True
    )
    status: Mapped[MarketplaceMessageStatus] = mapped_column(
        marketplace_message_status_enum, default=MarketplaceMessageStatus.VISIBLE, index=True
    )
    moderation_reason: Mapped[str] = mapped_column(String(120), default="")
    spam_score: Mapped[float] = mapped_column(Float, default=0.0)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    edited_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    channel: Mapped[MarketplaceCommunityChannel] = relationship(back_populates="messages")
    sender: Mapped[User] = relationship(foreign_keys=[sender_id])


class MarketplaceCommunityReaction(Base):
    __tablename__ = "marketplace_community_reactions"
    __table_args__ = (
        UniqueConstraint("message_id", "user_id", "emoji", name="uq_marketplace_community_reaction"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplace_community_messages.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    emoji: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MarketplaceCommunityReport(Base):
    __tablename__ = "marketplace_community_reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplace_community_messages.id", ondelete="CASCADE"), index=True
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(80))
    details: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[MarketplaceReportStatus] = mapped_column(
        marketplace_report_status_enum, default=MarketplaceReportStatus.OPEN, index=True
    )
    reviewed_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MarketplaceCommunityBan(Base):
    __tablename__ = "marketplace_community_bans"
    __table_args__ = (
        UniqueConstraint("marketplace_id", "user_id", name="uq_marketplace_community_ban"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    marketplace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    banned_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    reason: Mapped[str] = mapped_column(Text, default="")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MarketplaceCommunitySpamState(Base):
    """Per-user spam tracking inside a marketplace community."""

    __tablename__ = "marketplace_community_spam_states"
    __table_args__ = (
        UniqueConstraint("user_id", "marketplace_id", name="uq_marketplace_community_spam_state"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    marketplace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="CASCADE"), index=True
    )
    violation_count: Mapped[int] = mapped_column(Integer, default=0)
    last_message_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_normalized_body: Mapped[str] = mapped_column(Text, default="")
    muted_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class MarketplaceCommunityModerationLog(Base):
    __tablename__ = "marketplace_community_moderation_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    marketplace_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column(String(80))
    target_type: Mapped[str] = mapped_column(String(40), default="")
    target_id: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
