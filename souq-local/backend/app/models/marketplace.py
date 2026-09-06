"""Physical marketplace venues (e.g. Derb Ghallef) and their category trees."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models import Base

if TYPE_CHECKING:
    from app.models import SellerProfile


class Marketplace(Base):
    __tablename__ = "marketplaces"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(80), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    known_for: Mapped[str] = mapped_column(Text, default="")
    address: Mapped[str] = mapped_column(String(255), default="")
    district: Mapped[str] = mapped_column(String(120), default="")
    city: Mapped[str] = mapped_column(String(80), default="Casablanca", index=True)
    latitude: Mapped[float] = mapped_column(Float, default=0.0)
    longitude: Mapped[float] = mapped_column(Float, default=0.0)
    cover_image_url: Mapped[str] = mapped_column(String(512), default="")
    logo_image_url: Mapped[str] = mapped_column(String(512), default="")
    opening_hours: Mapped[dict] = mapped_column(JSONB, default=dict)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    display_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    categories: Mapped[list["MarketplaceCategory"]] = relationship(
        back_populates="marketplace",
        cascade="all, delete-orphan",
        order_by="MarketplaceCategory.display_order",
    )
    sellers: Mapped[list["SellerProfile"]] = relationship(back_populates="marketplace")


class MarketplaceCategory(Base):
    __tablename__ = "marketplace_categories"
    __table_args__ = (UniqueConstraint("marketplace_id", "slug", name="uq_marketplace_category_slug"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    marketplace_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="CASCADE"), index=True
    )
    parent_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("marketplace_categories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    name: Mapped[str] = mapped_column(String(120))
    slug: Mapped[str] = mapped_column(String(80), index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    icon: Mapped[str] = mapped_column(String(64), default="store")
    banner_image_url: Mapped[str] = mapped_column(String(512), default="")
    display_order: Mapped[int] = mapped_column(Integer, default=0, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    marketplace: Mapped[Marketplace] = relationship(back_populates="categories")
    parent: Mapped[MarketplaceCategory | None] = relationship(
        remote_side="MarketplaceCategory.id", back_populates="children"
    )
    children: Mapped[list["MarketplaceCategory"]] = relationship(back_populates="parent")
