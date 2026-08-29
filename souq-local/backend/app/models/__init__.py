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
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class AccountType(str, enum.Enum):
    CUSTOMER = "customer"
    PROVIDER = "provider"


class UserStatus(str, enum.Enum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    DELETED = "deleted"


class UserRole(str, enum.Enum):
    CUSTOMER = "customer"
    PROVIDER = "provider"
    ADMIN = "admin"
    SUPPORT = "support"


class PricingType(str, enum.Enum):
    FIXED = "fixed"
    OFFER = "offer"


class SubscriptionStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    TRIALING = "trialing"
    PAST_DUE = "past_due"
    PAYMENT_FAILED = "payment_failed"
    CANCELED = "canceled"
    EXPIRED = "expired"


class PlatformPaymentStatus(str, enum.Enum):
    PENDING = "pending"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"


class AdvertisingCampaignStatus(str, enum.Enum):
    PENDING = "pending"
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class VerificationStatus(str, enum.Enum):
    UNVERIFIED = "unverified"
    PENDING = "pending"
    VERIFIED = "verified"
    REJECTED = "rejected"


def _enum(enum_cls: type[enum.Enum], name: str) -> Enum:
    return Enum(
        enum_cls,
        name=name,
        values_callable=lambda cls: [member.value for member in cls],
        create_constraint=False,
        native_enum=True,
        validate_strings=True,
    )


account_type_enum = _enum(AccountType, "accounttype")
user_status_enum = _enum(UserStatus, "userstatus")
user_role_enum = _enum(UserRole, "userrole")
pricing_type_enum = _enum(PricingType, "pricingtype")
subscription_status_enum = _enum(SubscriptionStatus, "subscriptionstatus")
platform_payment_status_enum = _enum(PlatformPaymentStatus, "platformpaymentstatus")
advertising_campaign_status_enum = _enum(AdvertisingCampaignStatus, "advertisingcampaignstatus")
verification_status_enum = _enum(VerificationStatus, "verificationstatus")


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_type: Mapped[AccountType] = mapped_column(account_type_enum, nullable=False)
    display_name: Mapped[str] = mapped_column(String(120), default="")
    phone: Mapped[str] = mapped_column(String(32), default="")
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[UserStatus] = mapped_column(user_status_enum, default=UserStatus.ACTIVE)
    role: Mapped[UserRole] = mapped_column(user_role_enum, default=UserRole.CUSTOMER)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    premium_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    token_version: Mapped[int] = mapped_column(Integer, default=0)
    failed_login_attempts: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    profile_photo_url: Mapped[str] = mapped_column(String(512), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller_profile: Mapped["SellerProfile | None"] = relationship(back_populates="user", uselist=False)
    reviews_written: Mapped[list["Review"]] = relationship(back_populates="buyer")
    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    favorites: Mapped[list["Favorite"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    device_name: Mapped[str] = mapped_column(String(120), default="")
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(255), default="")
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="refresh_tokens")


class AuthToken(Base):
    __tablename__ = "auth_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    purpose: Mapped[str] = mapped_column(String(32), index=True)  # email_verify | password_reset
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SignupVerification(Base):
    __tablename__ = "signup_verifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), index=True)
    phone: Mapped[str] = mapped_column(String(32), default="")
    channel: Mapped[str] = mapped_column(String(16))  # email | phone
    code_hash: Mapped[str] = mapped_column(String(64))
    proof_token_hash: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    failed_attempts: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MfaFactor(Base):
    __tablename__ = "mfa_factors"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    factor_type: Mapped[str] = mapped_column(String(32), default="totp")
    secret_encrypted: Mapped[str] = mapped_column(String(512))
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    disabled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MfaRecoveryCode(Base):
    __tablename__ = "mfa_recovery_codes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    code_hash: Mapped[str] = mapped_column(String(64), unique=True)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slug: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    name_en: Mapped[str] = mapped_column(String(80))
    name_fr: Mapped[str] = mapped_column(String(80), default="")
    name_ar: Mapped[str] = mapped_column(String(80), default="")
    icon: Mapped[str] = mapped_column(String(32), default="store")

    sellers: Mapped[list["SellerProfile"]] = relationship(
        secondary="seller_categories", back_populates="categories"
    )


class SellerCategory(Base):
    __tablename__ = "seller_categories"

    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), primary_key=True)
    category_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("categories.id"), primary_key=True)


class SellerProfile(Base):
    __tablename__ = "seller_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), unique=True)
    business_name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    address: Mapped[str] = mapped_column(String(255))
    city: Mapped[str] = mapped_column(String(80), index=True)
    marketplace_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("marketplaces.id", ondelete="SET NULL"), nullable=True, index=True
    )
    market_zone: Mapped[str] = mapped_column(String(120), default="")
    market_street: Mapped[str] = mapped_column(String(120), default="")
    market_gallery: Mapped[str] = mapped_column(String(120), default="")
    shop_number: Mapped[str] = mapped_column(String(32), default="")
    market_floor: Mapped[str] = mapped_column(String(64), default="")
    nearby_landmark: Mapped[str] = mapped_column(String(255), default="")
    custom_marketplace_name: Mapped[str] = mapped_column(String(160), default="")
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    phone: Mapped[str] = mapped_column(String(32), default="")
    cover_image_url: Mapped[str] = mapped_column(String(512), default="")
    logo_image_url: Mapped[str] = mapped_column(String(512), default="")
    opening_hours: Mapped[dict] = mapped_column(JSONB, default=dict)
    website_url: Mapped[str] = mapped_column(String(255), default="")
    instagram_url: Mapped[str] = mapped_column(String(255), default="")
    facebook_url: Mapped[str] = mapped_column(String(255), default="")
    tiktok_url: Mapped[str] = mapped_column(String(255), default="")
    whatsapp_number: Mapped[str] = mapped_column(String(32), default="")
    payment_methods: Mapped[list] = mapped_column(JSONB, default=lambda: ["cash"])
    delivery_methods: Mapped[list] = mapped_column(JSONB, default=lambda: ["in_store"])
    service_areas: Mapped[list] = mapped_column(JSONB, default=list)
    avg_response_minutes: Mapped[int] = mapped_column(Integer, default=0)
    inquiry_count: Mapped[int] = mapped_column(Integer, default=0)
    favorite_count: Mapped[int] = mapped_column(Integer, default=0)
    contact_click_count: Mapped[int] = mapped_column(Integer, default=0)
    profile_view_count: Mapped[int] = mapped_column(Integer, default=0)
    achievement_stars: Mapped[int] = mapped_column(Integer, default=0)
    golden_crowns: Mapped[int] = mapped_column(Integer, default=0)
    average_rating: Mapped[float] = mapped_column(Float, default=0.0)
    review_count: Mapped[int] = mapped_column(Integer, default=0)
    avg_product_quality: Mapped[float] = mapped_column(Float, default=0.0)
    avg_customer_service: Mapped[float] = mapped_column(Float, default=0.0)
    avg_communication: Mapped[float] = mapped_column(Float, default=0.0)
    avg_trustworthiness: Mapped[float] = mapped_column(Float, default=0.0)
    verification_status: Mapped[VerificationStatus] = mapped_column(
        verification_status_enum, default=VerificationStatus.UNVERIFIED
    )
    is_premium: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="seller_profile")
    marketplace: Mapped["Marketplace | None"] = relationship(back_populates="sellers")
    categories: Mapped[list[Category]] = relationship(
        secondary="seller_categories", back_populates="sellers"
    )
    products: Mapped[list["Product"]] = relationship(back_populates="seller", cascade="all, delete-orphan")
    services: Mapped[list["Service"]] = relationship(back_populates="seller", cascade="all, delete-orphan")
    reviews: Mapped[list["Review"]] = relationship(back_populates="seller", cascade="all, delete-orphan")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    pricing_type: Mapped[PricingType] = mapped_column(pricing_type_enum, default=PricingType.FIXED)
    price_negotiable: Mapped[bool] = mapped_column(Boolean, default=False)
    availability_note: Mapped[str] = mapped_column(String(160), default="")
    warranty_note: Mapped[str] = mapped_column(String(160), default="")
    accepted_payment_methods: Mapped[list] = mapped_column(JSONB, default=list)
    delivery_options: Mapped[list] = mapped_column(JSONB, default=list)
    delivery_available: Mapped[bool] = mapped_column(Boolean, default=False)
    pickup_only: Mapped[bool] = mapped_column(Boolean, default=True)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    media_urls: Mapped[list] = mapped_column(JSONB, default=list)
    category_slug: Mapped[str] = mapped_column(String(80), default="")
    stock_quantity: Mapped[int] = mapped_column(Integer, default=1)  # availability hint, not warehouse stock
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    is_paused: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller: Mapped[SellerProfile] = relationship(back_populates="products")


class Service(Base):
    __tablename__ = "services"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    price_min_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    price_max_mad: Mapped[float | None] = mapped_column(Numeric(12, 2, asdecimal=False), nullable=True)
    pricing_model: Mapped[str] = mapped_column(String(32), default="fixed_price")
    pricing_type: Mapped[PricingType] = mapped_column(pricing_type_enum, default=PricingType.FIXED)
    price_negotiable: Mapped[bool] = mapped_column(Boolean, default=False)
    category_slug: Mapped[str] = mapped_column(String(80), default="")
    coverage_areas: Mapped[list] = mapped_column(JSONB, default=list)
    image_url: Mapped[str] = mapped_column(String(512), default="")
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    seller: Mapped[SellerProfile] = relationship(back_populates="services")


class ShareLink(Base):
    __tablename__ = "share_links"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    token: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    resource_type: Mapped[str] = mapped_column(String(32))
    resource_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (UniqueConstraint("seller_id", "buyer_id", name="uq_review_seller_buyer"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id"), index=True)
    buyer_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    # Computed overall (rounded mean of the four category scores).
    rating: Mapped[int] = mapped_column(Integer)
    product_quality: Mapped[int] = mapped_column(Integer)
    customer_service: Mapped[int] = mapped_column(Integer)
    communication: Mapped[int] = mapped_column(Integer)
    trustworthiness: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    seller: Mapped[SellerProfile] = relationship(back_populates="reviews")
    buyer: Mapped[User] = relationship(back_populates="reviews_written")

    @property
    def overall_rating(self) -> float:
        return round(
            (
                self.product_quality
                + self.customer_service
                + self.communication
                + self.trustworthiness
            )
            / 4.0,
            2,
        )


class WarningZone(Base):
    __tablename__ = "warning_zones"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(160))
    description: Mapped[str] = mapped_column(Text, default="")
    city: Mapped[str] = mapped_column(String(80), index=True)
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    radius_meters: Mapped[float] = mapped_column(Float, default=200.0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (
        # Partial uniqueness is enforced in migration 008; keep ORM indexes aligned.
        Index("ix_favorites_user_product", "user_id", "product_id"),
        Index("ix_favorites_user_seller", "user_id", "seller_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=True, index=True
    )
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="favorites")
    product: Mapped["Product | None"] = relationship()
    seller: Mapped["SellerProfile | None"] = relationship()


class SellerFollow(Base):
    __tablename__ = "seller_follows"
    __table_args__ = (UniqueConstraint("user_id", "seller_id", name="uq_follow_user_seller"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class SavedSearch(Base):
    __tablename__ = "saved_searches"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    query: Mapped[str] = mapped_column(String(160), default="")
    city: Mapped[str] = mapped_column(String(80), default="")
    category: Mapped[str] = mapped_column(String(80), default="")
    marketplace_slug: Mapped[str] = mapped_column(String(80), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RecentlyViewed(Base):
    __tablename__ = "recently_viewed"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=True)
    viewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reporter_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=True
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=True)
    reported_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    reason: Mapped[str] = mapped_column(String(80))
    details: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), default="open", index=True)
    reviewed_by_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    resolution_notes: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class UserBlock(Base):
    __tablename__ = "user_blocks"
    __table_args__ = (UniqueConstraint("blocker_id", "blocked_id", name="uq_user_block"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    blocker_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    blocked_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ContactEvent(Base):
    __tablename__ = "contact_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    channel: Mapped[str] = mapped_column(String(32))  # call|whatsapp|email|message|website|sms
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        UniqueConstraint("participant_a_id", "participant_b_id", name="uq_conversation_participants"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Canonical unordered pair: participant_a_id < participant_b_id (both users).
    participant_a_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    participant_b_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    # Optional storefront that was contacted (inquiry analytics); null for pure user↔user.
    context_seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True, index=True
    )
    last_message_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    messages: Mapped[list["Message"]] = relationship(back_populates="conversation", cascade="all, delete-orphan")

    def other_participant(self, user_id: uuid.UUID) -> uuid.UUID:
        if self.participant_a_id == user_id:
            return self.participant_b_id
        if self.participant_b_id == user_id:
            return self.participant_a_id
        raise ValueError("user is not a participant")

    def involves(self, user_id: uuid.UUID) -> bool:
        return user_id in {self.participant_a_id, self.participant_b_id}


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("conversations.id", ondelete="CASCADE"), index=True)
    sender_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    body: Mapped[str] = mapped_column(Text)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation: Mapped[Conversation] = relationship(back_populates="messages")


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(160))
    body: Mapped[str] = mapped_column(Text, default="")
    kind: Mapped[str] = mapped_column(String(40), default="general")
    data: Mapped[dict] = mapped_column(JSONB, default=dict)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user: Mapped[User] = relationship(back_populates="notifications")


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(40), unique=True)
    name: Mapped[str] = mapped_column(String(80))
    description: Mapped[str] = mapped_column(Text, default="")
    price_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    billing_period_days: Mapped[int] = mapped_column(Integer, default=30)
    features: Mapped[list] = mapped_column(JSONB, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Subscription(Base):
    __tablename__ = "subscriptions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    plan_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("subscription_plans.id"))
    status: Mapped[SubscriptionStatus] = mapped_column(
        subscription_status_enum, default=SubscriptionStatus.ACTIVE
    )
    current_period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    current_period_end: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    provider: Mapped[str] = mapped_column(String(40), default="manual")
    provider_reference: Mapped[str] = mapped_column(String(160), default="")
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    plan: Mapped[SubscriptionPlan] = relationship()


class SubscriptionEvent(Base):
    __tablename__ = "subscription_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    plan_code: Mapped[str] = mapped_column(String(40))
    event_type: Mapped[str] = mapped_column(String(64), index=True)
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DribexServicePayment(Base):
    """Payment TO Dribex for Dribex-owned services (subscriptions, advertising).

    Never used for buyer↔seller product purchases.
    """

    __tablename__ = "dribex_service_payments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    seller_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True
    )
    service_type: Mapped[str] = mapped_column(String(32))
    service_code: Mapped[str] = mapped_column(String(64))
    amount_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    currency: Mapped[str] = mapped_column(String(8), default="mad")
    status: Mapped[PlatformPaymentStatus] = mapped_column(
        platform_payment_status_enum, default=PlatformPaymentStatus.PENDING
    )
    provider: Mapped[str] = mapped_column(String(40), default="manual")
    provider_reference: Mapped[str] = mapped_column(String(160), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class PaymentWebhookEvent(Base):
    __tablename__ = "payment_webhook_events"
    __table_args__ = (UniqueConstraint("provider", "event_id", name="uq_payment_webhook_provider_event"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    provider: Mapped[str] = mapped_column(String(40))
    event_id: Mapped[str] = mapped_column(String(160))
    payload_hash: Mapped[str] = mapped_column(String(64))
    processed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AdvertisingPackage(Base):
    __tablename__ = "advertising_packages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(64), unique=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    placement_type: Mapped[str] = mapped_column(String(40))
    price_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    duration_days: Mapped[int] = mapped_column(Integer)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AdvertisingCampaign(Base):
    __tablename__ = "advertising_campaigns"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    seller_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("seller_profiles.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    package_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("advertising_packages.id"))
    payment_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("dribex_service_payments.id", ondelete="SET NULL"), nullable=True
    )
    status: Mapped[AdvertisingCampaignStatus] = mapped_column(
        advertising_campaign_status_enum, default=AdvertisingCampaignStatus.PENDING
    )
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    package: Mapped[AdvertisingPackage] = relationship()
    payment: Mapped["DribexServicePayment | None"] = relationship()


class SecurityEvent(Base):
    __tablename__ = "security_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_type: Mapped[str] = mapped_column(String(80), index=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AdminAuditLog(Base):
    __tablename__ = "admin_audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    action: Mapped[str] = mapped_column(String(80))
    target_type: Mapped[str] = mapped_column(String(40), default="")
    target_id: Mapped[str] = mapped_column(String(64), default="")
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RewardedAdSessionStatus(str, enum.Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    EXPIRED = "expired"


class RewardedAdSession(Base):
    """Short-lived session while a user watches a rewarded advertisement."""

    __tablename__ = "rewarded_ad_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    feature_code: Mapped[str] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(16), default=RewardedAdSessionStatus.PENDING.value, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class RewardedAdGrant(Base):
    """Temporary entitlement granted after server-verified rewarded ad completion."""

    __tablename__ = "rewarded_ad_grants"
    __table_args__ = (
        UniqueConstraint("provider", "provider_reward_id", name="uq_rewarded_ad_grants_provider_reward"),
        Index("ix_rewarded_ad_grants_user_feature", "user_id", "feature_code"),
        Index("ix_rewarded_ad_grants_expires_at", "expires_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE")
    )
    feature_code: Mapped[str] = mapped_column(String(64))
    session_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rewarded_ad_sessions.id", ondelete="SET NULL"), nullable=True
    )
    provider: Mapped[str] = mapped_column(String(32), default="internal")
    provider_reward_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    granted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class PlatformAdCampaignStatus(str, enum.Enum):
    DRAFT = "draft"
    SCHEDULED = "scheduled"
    ACTIVE = "active"
    PAUSED = "paused"
    EXPIRED = "expired"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class PlatformAdPaymentStatus(str, enum.Enum):
    PENDING = "pending"
    PAID = "paid"
    CANCELLED = "cancelled"
    REFUNDED = "refunded"


platform_ad_campaign_status_enum = _enum(PlatformAdCampaignStatus, "platformadcampaignstatus")
platform_ad_payment_status_enum = _enum(PlatformAdPaymentStatus, "platformadpaymentstatus")


class PlatformAdvertisement(Base):
    """Admin-managed promotional campaign shown on the public storefront."""

    __tablename__ = "platform_advertisements"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    advertiser_name: Mapped[str] = mapped_column(String(200), default="")
    campaign_name: Mapped[str] = mapped_column(String(200), default="")
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str] = mapped_column(String(2048))
    video_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    target_url: Mapped[str] = mapped_column(String(2048))
    contact_info: Mapped[str] = mapped_column(String(500), default="")
    placement: Mapped[str] = mapped_column(String(64), default="homepage_top", index=True)
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[PlatformAdCampaignStatus] = mapped_column(
        platform_ad_campaign_status_enum,
        default=PlatformAdCampaignStatus.DRAFT,
        index=True,
    )
    priority: Mapped[int] = mapped_column(Integer, default=5)
    max_impressions: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_impressions_per_user_per_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    min_interval_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    impression_count: Mapped[int] = mapped_column(Integer, default=0)
    click_count: Mapped[int] = mapped_column(Integer, default=0)
    payment_status: Mapped[PlatformAdPaymentStatus] = mapped_column(
        platform_ad_payment_status_enum,
        default=PlatformAdPaymentStatus.PENDING,
    )
    payment_override: Mapped[bool] = mapped_column(Boolean, default=False)
    internal_notes: Mapped[str] = mapped_column(Text, default="")
    created_by_admin_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    target_city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    target_marketplace_slug: Mapped[str | None] = mapped_column(String(80), nullable=True, index=True)
    target_category_slug: Mapped[str | None] = mapped_column(String(100), nullable=True)
    target_listing_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    target_platform: Mapped[str] = mapped_column(String(20), default="all")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)

    impressions: Mapped[list["AdImpression"]] = relationship(back_populates="campaign")
    clicks: Mapped[list["AdClick"]] = relationship(back_populates="campaign")


class AdImpression(Base):
    __tablename__ = "ad_impressions"
    __table_args__ = (
        UniqueConstraint("campaign_id", "view_key", name="uq_ad_impressions_campaign_view_key"),
        Index("ix_ad_impressions_campaign_recorded", "campaign_id", "recorded_at"),
        Index("ix_ad_impressions_campaign_viewer_day", "campaign_id", "viewer_key", "recorded_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("platform_advertisements.id", ondelete="CASCADE"),
        index=True,
    )
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    viewer_key: Mapped[str] = mapped_column(String(128), default="")
    placement: Mapped[str] = mapped_column(String(64), default="")
    platform: Mapped[str] = mapped_column(String(20), default="web")
    view_key: Mapped[str] = mapped_column(String(128))

    campaign: Mapped[PlatformAdvertisement] = relationship(back_populates="impressions")


class AdClick(Base):
    __tablename__ = "ad_clicks"
    __table_args__ = (
        UniqueConstraint("campaign_id", "click_key", name="uq_ad_clicks_campaign_click_key"),
        Index("ix_ad_clicks_campaign_recorded", "campaign_id", "recorded_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("platform_advertisements.id", ondelete="CASCADE"),
        index=True,
    )
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    viewer_key: Mapped[str] = mapped_column(String(128), default="")
    placement: Mapped[str] = mapped_column(String(64), default="")
    platform: Mapped[str] = mapped_column(String(20), default="web")
    click_key: Mapped[str] = mapped_column(String(128))

    campaign: Mapped[PlatformAdvertisement] = relationship(back_populates="clicks")


class PrivacyRequestType(str, enum.Enum):
    ACCESS = "access"
    RECTIFICATION = "rectification"
    ERASURE = "erasure"
    OPPOSITION = "opposition"
    OTHER = "other"


class PrivacyRequestStatus(str, enum.Enum):
    PENDING = "pending"
    IN_REVIEW = "in_review"
    COMPLETED = "completed"
    REJECTED = "rejected"
    CANCELLED = "cancelled"


privacy_request_type_enum = _enum(PrivacyRequestType, "privacyrequesttype")
privacy_request_status_enum = _enum(PrivacyRequestStatus, "privacyrequeststatus")


class PrivacyRequest(Base):
    __tablename__ = "privacy_requests"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    request_type: Mapped[PrivacyRequestType] = mapped_column(privacy_request_type_enum, nullable=False)
    status: Mapped[PrivacyRequestStatus] = mapped_column(
        privacy_request_status_enum, default=PrivacyRequestStatus.PENDING
    )
    details: Mapped[str] = mapped_column(Text, default="")
    resolution_notes: Mapped[str] = mapped_column(Text, default="")
    reviewer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(512), default="")
    audit_metadata: Mapped[dict] = mapped_column(JSONB, default=dict)


class UserConsent(Base):
    __tablename__ = "user_consents"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    consent_type: Mapped[str] = mapped_column(String(64), index=True)
    purpose: Mapped[str] = mapped_column(String(255), default="")
    granted: Mapped[bool] = mapped_column(Boolean, nullable=False)
    policy_version: Mapped[str] = mapped_column(String(32), default="")
    language: Mapped[str] = mapped_column(String(8), default="en")
    source: Mapped[str] = mapped_column(String(64), default="api")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    withdrawn_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(512), default="")


class SubscriptionAgreementRecord(Base):
    __tablename__ = "subscription_agreement_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    subscription_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="SET NULL"), nullable=True, index=True
    )
    plan_code: Mapped[str] = mapped_column(String(40))
    plan_price_mad: Mapped[float] = mapped_column(Numeric(12, 2, asdecimal=False))
    billing_period_days: Mapped[int] = mapped_column(Integer)
    policy_id: Mapped[str] = mapped_column(String(64), default="subscription_terms")
    policy_version: Mapped[str] = mapped_column(String(32))
    document_hash: Mapped[str] = mapped_column(String(64), default="")
    language: Mapped[str] = mapped_column(String(8), default="en")
    accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(512), default="")
    authentication_method: Mapped[str] = mapped_column(String(32), default="bearer_session")
    provider_reference: Mapped[str] = mapped_column(String(120), default="")


class UserMediaObject(Base):
    __tablename__ = "user_media_objects"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    blob_key: Mapped[str] = mapped_column(String(512), unique=True, index=True)
    public_url: Mapped[str] = mapped_column(String(512), default="")
    purpose: Mapped[str] = mapped_column(String(40))
    content_type: Mapped[str] = mapped_column(String(64), default="")
    bytes_size: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(24), default="active")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class LegalAcceptance(Base):
    __tablename__ = "legal_acceptances"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "policy_id",
            "policy_version",
            name="uq_legal_acceptance_user_policy_version",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    policy_id: Mapped[str] = mapped_column(String(64), index=True)
    policy_version: Mapped[str] = mapped_column(String(32))
    language: Mapped[str] = mapped_column(String(8), default="en")
    accepted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ip_address: Mapped[str] = mapped_column(String(64), default="")
    user_agent: Mapped[str] = mapped_column(String(512), default="")
    document_hash: Mapped[str] = mapped_column(String(64), default="")
    authentication_method: Mapped[str] = mapped_column(String(32), default="bearer_session")
    source: Mapped[str] = mapped_column(String(64), default="legal_accept")
    session_reference: Mapped[str] = mapped_column(String(128), default="")


# Re-export community models for Alembic metadata and imports.
from app.models.community import (  # noqa: E402,F401
    City,
    CommunityChannel,
    CommunityChannelCategory,
    CommunityCityBan,
    CommunityMembership,
    CommunityMessage,
    CommunityMessageStatus,
    CommunityModerationLog,
    CommunityReaction,
    CommunityReport,
    CommunityReportStatus,
    CommunityUserBlock,
    CommunityUserMute,
    DEFAULT_CHANNEL_SPECS,
)
from app.models.geography import Country  # noqa: E402,F401
from app.models.marketplace import Marketplace, MarketplaceCategory  # noqa: E402,F401
from app.models.marketplace_community import (  # noqa: E402,F401
    MarketplaceCommunityBan,
    MarketplaceCommunityChannel,
    MarketplaceCommunityMembership,
    MarketplaceCommunityMessage,
    MarketplaceCommunityModerationLog,
    MarketplaceCommunityReaction,
    MarketplaceCommunityReport,
    MarketplaceCommunitySpamState,
)
