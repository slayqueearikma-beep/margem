"""City community chat models — scalable for future community types."""

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


class CommunityChannelCategory(str, enum.Enum):
    GENERAL = "general"
    MARKETPLACE = "marketplace"
    RECOMMENDATIONS = "recommendations"
    QUESTIONS = "questions"
    EVENTS = "events"
    JOBS = "jobs"
    HOUSING = "housing"
    SERVICES = "services"
    FOOD = "food"
    TRANSPORTATION = "transportation"
    EMERGENCY_ALERTS = "emergency_alerts"
    ANNOUNCEMENTS = "announcements"


class CommunityMessageStatus(str, enum.Enum):
    VISIBLE = "visible"
    PENDING_MODERATION = "pending_moderation"
    HIDDEN = "hidden"
    DELETED = "deleted"


class CommunityReportStatus(str, enum.Enum):
    OPEN = "open"
    REVIEWED = "reviewed"
    DISMISSED = "dismissed"
    ACTIONED = "actioned"


community_channel_category_enum = _enum(CommunityChannelCategory, "communitychannelcategory")
community_message_status_enum = _enum(CommunityMessageStatus, "communitymessagestatus")
community_report_status_enum = _enum(CommunityReportStatus, "communityreportstatus")

DEFAULT_CHANNEL_SPECS: list[tuple[CommunityChannelCategory, str, str]] = [
    (CommunityChannelCategory.GENERAL, "General", "Open discussion for everyone in the city"),
    (CommunityChannelCategory.MARKETPLACE, "Marketplace", "Buy, sell, and trade locally"),
    (CommunityChannelCategory.RECOMMENDATIONS, "Recommendations", "Share trusted local picks"),
    (CommunityChannelCategory.QUESTIONS, "Questions", "Ask the community for help"),
    (CommunityChannelCategory.EVENTS, "Events", "Local events and meetups"),
    (CommunityChannelCategory.JOBS, "Jobs", "Job postings and opportunities"),
    (CommunityChannelCategory.HOUSING, "Housing", "Rentals, roommates, and real estate"),
    (CommunityChannelCategory.SERVICES, "Services", "Local service providers"),
    (CommunityChannelCategory.FOOD, "Food", "Restaurants, cafés, and food spots"),
    (CommunityChannelCategory.TRANSPORTATION, "Transportation", "Transit tips and ride sharing"),
    (CommunityChannelCategory.EMERGENCY_ALERTS, "Emergency Alerts", "Time-sensitive safety updates"),
    (CommunityChannelCategory.ANNOUNCEMENTS, "Announcements", "Official community announcements"),
]


class City(Base):
    """Supported city with a dedicated public community."""

    __tablename__ = "cities"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    member_count: Mapped[int] = mapped_column(Integer, default=0)
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    channels: Mapped[list["CommunityChannel"]] = relationship(
        back_populates="city", cascade="all, delete-orphan"
    )
    memberships: Mapped[list["CommunityMembership"]] = relationship(
        back_populates="city", cascade="all, delete-orphan"
    )


class CommunityChannel(Base):
    """Category channel inside a city (General, Marketplace, etc.)."""

    __tablename__ = "community_channels"
    __table_args__ = (
        UniqueConstraint("city_id", "category", name="uq_community_channel_city_category"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    city_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cities.id", ondelete="CASCADE"), index=True)
    category: Mapped[CommunityChannelCategory] = mapped_column(community_channel_category_enum, index=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    message_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    city: Mapped[City] = relationship(back_populates="channels")
    messages: Mapped[list["CommunityMessage"]] = relationship(
        back_populates="channel", cascade="all, delete-orphan"
    )


class CommunityMembership(Base):
    __tablename__ = "community_memberships"
    __table_args__ = (
        UniqueConstraint("user_id", "city_id", name="uq_community_membership"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    city_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cities.id", ondelete="CASCADE"), index=True)
    is_home_city: Mapped[bool] = mapped_column(Boolean, default=False)
    notification_prefs: Mapped[dict] = mapped_column(JSONB, default=dict)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    city: Mapped[City] = relationship(back_populates="memberships")
    user: Mapped[User] = relationship()


class CommunityMessage(Base):
    __tablename__ = "community_messages"
    __table_args__ = (
        Index("ix_community_messages_channel_created", "channel_id", "created_at"),
        Index("ix_community_messages_thread_root", "thread_root_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("community_channels.id", ondelete="CASCADE"), index=True
    )
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    body: Mapped[str] = mapped_column(Text, default="")
    reply_to_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("community_messages.id", ondelete="SET NULL"), nullable=True, index=True
    )
    thread_root_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("community_messages.id", ondelete="SET NULL"), nullable=True
    )
    attachments: Mapped[list] = mapped_column(JSONB, default=list)
    link_preview: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    mentions: Mapped[list] = mapped_column(JSONB, default=list)
    hashtags: Mapped[list] = mapped_column(JSONB, default=list)
    language: Mapped[str] = mapped_column(String(16), default="")
    status: Mapped[CommunityMessageStatus] = mapped_column(
        community_message_status_enum, default=CommunityMessageStatus.VISIBLE, index=True
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

    channel: Mapped[CommunityChannel] = relationship(back_populates="messages")
    sender: Mapped[User] = relationship(foreign_keys=[sender_id])
    reactions: Mapped[list["CommunityReaction"]] = relationship(
        back_populates="message", cascade="all, delete-orphan"
    )


class CommunityReaction(Base):
    __tablename__ = "community_reactions"
    __table_args__ = (
        UniqueConstraint("message_id", "user_id", "emoji", name="uq_community_reaction"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("community_messages.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    emoji: Mapped[str] = mapped_column(String(32))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    message: Mapped[CommunityMessage] = relationship(back_populates="reactions")


class CommunityReport(Base):
    __tablename__ = "community_reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("community_messages.id", ondelete="CASCADE"), index=True
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(80))
    details: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[CommunityReportStatus] = mapped_column(
        community_report_status_enum, default=CommunityReportStatus.OPEN, index=True
    )
    reviewed_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CommunityUserBlock(Base):
    __tablename__ = "community_user_blocks"
    __table_args__ = (
        UniqueConstraint("blocker_id", "blocked_id", name="uq_community_user_block"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    blocker_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    blocked_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CommunityUserMute(Base):
    __tablename__ = "community_user_mutes"
    __table_args__ = (
        UniqueConstraint("muter_id", "muted_id", name="uq_community_user_mute"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    muter_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    muted_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CommunityCityBan(Base):
    __tablename__ = "community_city_bans"
    __table_args__ = (
        UniqueConstraint("city_id", "user_id", name="uq_community_city_ban"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    city_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("cities.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    banned_by_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reason: Mapped[str] = mapped_column(Text, default="")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CommunityModerationLog(Base):
    __tablename__ = "community_moderation_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action: Mapped[str] = mapped_column(String(80))
    target_type: Mapped[str] = mapped_column(String(40), default="")
    target_id: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
