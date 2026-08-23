from datetime import datetime
from enum import Enum
from urllib.parse import urlparse
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.services.password_policy import validate_password_strength
from app.services.service_pricing import PricingModel, normalize_service_pricing


def _validate_http_url(value: str, *, field_name: str = "url") -> str:
    cleaned = value.strip()
    if not cleaned:
        return ""
    parsed = urlparse(cleaned)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"{field_name} must be an absolute http(s) URL")
    if len(cleaned) > 2048:
        raise ValueError(f"{field_name} is too long")
    return cleaned


def _validate_media_urls(urls: list[str]) -> list[str]:
    if len(urls) > 12:
        raise ValueError("At most 12 media URLs are allowed")
    return [_validate_http_url(u, field_name="media_urls") for u in urls if u and u.strip()]


class AccountType(str, Enum):
    CUSTOMER = "customer"
    PROVIDER = "provider"


class PricingType(str, Enum):
    FIXED = "fixed"
    OFFER = "offer"


def _normalize_account_type(value) -> AccountType:
    if isinstance(value, AccountType):
        return value
    raw = str(value).strip().lower()
    if raw in {"buyer", "customer"}:
        return AccountType.CUSTOMER
    if raw in {"seller", "provider"}:
        return AccountType.PROVIDER
    return AccountType(raw)


class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    # Optional — defaults to buyer. Sellers unlock storefront later on the same account.
    account_type: AccountType = AccountType.CUSTOMER
    display_name: str = Field(default="", max_length=120)
    signup_proof: str = Field(min_length=20, max_length=128)

    @field_validator("account_type", mode="before")
    @classmethod
    def normalize_account_type(cls, value):
        return _normalize_account_type(value)

    @field_validator("password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        validate_password_strength(value)
        return value


class SignupOtpSendRequest(BaseModel):
    email: EmailStr
    phone: str = Field(default="", max_length=32)
    channel: str = Field(pattern=r"^(email|phone)$")


class SignupOtpVerifyRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")
    channel: str = Field(pattern=r"^(email|phone)$")


class SignupOtpSendResponse(BaseModel):
    channel: str
    destination_masked: str
    dev_code: str | None = None


class UserRegisterFirebase(BaseModel):
    firebase_uid: str
    email: EmailStr
    account_type: AccountType = AccountType.CUSTOMER
    display_name: str = ""


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class UserOut(BaseModel):
    id: UUID
    email: str
    account_type: AccountType
    display_name: str
    phone: str = ""
    email_verified: bool = False
    is_premium: bool = False
    premium_until: datetime | None = None
    role: str = "customer"
    status: str = "active"
    mfa_enabled: bool = False
    has_seller_profile: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_user(cls, user, *, has_seller_profile: bool = False) -> "UserOut":
        return cls(
            id=user.id,
            email=user.email,
            account_type=user.account_type,
            display_name=user.display_name,
            phone=getattr(user, "phone", "") or "",
            email_verified=getattr(user, "email_verified_at", None) is not None,
            is_premium=bool(getattr(user, "is_premium", False)),
            premium_until=getattr(user, "premium_until", None),
            role=getattr(user, "role", None).value if getattr(user, "role", None) else "customer",
            status=getattr(user, "status", None).value if getattr(user, "status", None) else "active",
            mfa_enabled=bool(getattr(user, "mfa_enabled", False)),
            has_seller_profile=has_seller_profile,
            created_at=user.created_at,
        )


class TokenResponse(BaseModel):
    access_token: str = ""
    refresh_token: str = ""
    token_type: str = "bearer"
    expires_in: int = 0
    user: UserOut | None = None
    mfa_required: bool = False
    mfa_token: str | None = None


class MfaEnrollOut(BaseModel):
    secret: str
    otpauth_uri: str


class MfaConfirmOut(BaseModel):
    recovery_codes: list[str]


class MfaCodeRequest(BaseModel):
    code: str = Field(min_length=6, max_length=16)


class MfaLoginRequest(BaseModel):
    mfa_token: str = Field(min_length=6, max_length=256)
    code: str = Field(min_length=6, max_length=16)


class MfaDisableRequest(BaseModel):
    code: str = Field(min_length=6, max_length=16)
    password: str = Field(min_length=1, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=512)


class DeleteAccountRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)
    confirmation: str = Field(description="Must equal DELETE")

    @field_validator("confirmation")
    @classmethod
    def must_confirm(cls, value: str) -> str:
        if value.strip() != "DELETE":
            raise ValueError("confirmation must be DELETE")
        return value


class CategoryOut(BaseModel):
    id: UUID
    slug: str
    name_en: str
    name_fr: str
    name_ar: str
    icon: str

    model_config = {"from_attributes": True}


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    pricing_type: PricingType = PricingType.FIXED
    price_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    availability_note: str = Field(default="", max_length=160)
    warranty_note: str = Field(default="", max_length=160)
    delivery_available: bool = False
    pickup_only: bool = True
    image_url: str = ""
    media_urls: list[str] = Field(default_factory=list)
    video_url: str = Field(default="", max_length=512)
    category_slug: str = Field(default="", max_length=80)
    stock_quantity: int = Field(default=1, ge=0, le=1_000_000)
    is_featured: bool = False

    @field_validator("pricing_type", mode="before")
    @classmethod
    def normalize_pricing_type(cls, value):
        if value in {True, "true", "negotiable", "offer"}:
            return PricingType.OFFER
        if value in {False, "false", "fixed"}:
            return PricingType.FIXED
        return value

    @field_validator("price_mad")
    @classmethod
    def validate_fixed_price(cls, value: float | None, info):
        pricing_type = info.data.get("pricing_type", PricingType.FIXED)
        if pricing_type == PricingType.OFFER:
            return None
        if value is None:
            raise ValueError("Fixed price listings require a price in MAD")
        return value

    @field_validator("category_slug")
    @classmethod
    def validate_category_slug(cls, value: str) -> str:
        from app.data.marketplace_categories import MARKETPLACE_CATEGORY_SLUGS

        cleaned = value.strip()
        if cleaned and cleaned not in MARKETPLACE_CATEGORY_SLUGS:
            raise ValueError("Unknown category")
        return cleaned

    @field_validator("image_url", "video_url")
    @classmethod
    def validate_optional_urls(cls, value: str) -> str:
        return _validate_http_url(value)

    @field_validator("media_urls")
    @classmethod
    def validate_media(cls, value: list[str]) -> list[str]:
        return _validate_media_urls(value)


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = None
    pricing_type: PricingType | None = None
    price_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    availability_note: str | None = Field(default=None, max_length=160)
    warranty_note: str | None = Field(default=None, max_length=160)
    delivery_available: bool | None = None
    pickup_only: bool | None = None
    image_url: str | None = None
    media_urls: list[str] | None = None
    video_url: str | None = Field(default=None, max_length=512)
    category_slug: str | None = Field(default=None, max_length=80)
    is_available: bool | None = None
    stock_quantity: int | None = Field(default=None, ge=0, le=1_000_000)
    is_hidden: bool | None = None
    is_featured: bool | None = None
    is_paused: bool | None = None

    @field_validator("image_url", "video_url")
    @classmethod
    def validate_optional_urls(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_http_url(value)

    @field_validator("media_urls")
    @classmethod
    def validate_media(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        return _validate_media_urls(value)


class ProductOut(BaseModel):
    id: UUID
    name: str
    description: str
    pricing_type: PricingType = PricingType.FIXED
    price_mad: float | None
    price_negotiable: bool = False
    availability_note: str = ""
    warranty_note: str = ""
    delivery_available: bool = False
    pickup_only: bool = True
    image_url: str
    media_urls: list = Field(default_factory=list)
    video_url: str = ""
    category_slug: str = ""
    is_available: bool
    stock_quantity: int = 1
    is_hidden: bool = False
    is_featured: bool = False
    is_paused: bool = False

    model_config = {"from_attributes": True}


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = ""
    pricing_type: PricingType = PricingType.FIXED
    pricing_model: PricingModel = PricingModel.FIXED_PRICE
    price_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_min_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_max_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    category_slug: str = Field(default="", max_length=80)
    coverage_areas: list[str] = Field(default_factory=list)
    image_url: str = ""
    is_featured: bool = False

    @field_validator("pricing_type", mode="before")
    @classmethod
    def normalize_pricing_type(cls, value):
        if value in {True, "true", "negotiable", "offer"}:
            return PricingType.OFFER
        if value in {False, "false", "fixed"}:
            return PricingType.FIXED
        return value

    @field_validator("category_slug")
    @classmethod
    def validate_category_slug(cls, value: str) -> str:
        from app.data.marketplace_categories import MARKETPLACE_CATEGORY_SLUGS

        cleaned = value.strip()
        if cleaned and cleaned not in MARKETPLACE_CATEGORY_SLUGS:
            raise ValueError("Unknown category")
        return cleaned

    @field_validator("image_url")
    @classmethod
    def validate_image_url(cls, value: str) -> str:
        return _validate_http_url(value)

    @model_validator(mode="before")
    @classmethod
    def legacy_pricing_fields(cls, data):
        if not isinstance(data, dict) or "pricing_model" in data:
            return data
        if data.get("price_negotiable"):
            data["pricing_model"] = PricingModel.NEGOTIABLE
        elif data.get("price_mad") is None:
            data["pricing_model"] = PricingModel.REQUEST_QUOTE
        return data

    def normalized_pricing(self) -> dict:
        return normalize_service_pricing(self.model_dump())


class ServiceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = None
    pricing_type: PricingType | None = None
    pricing_model: PricingModel | None = None
    price_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_min_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    price_max_mad: float | None = Field(default=None, ge=0, le=10_000_000)
    category_slug: str | None = Field(default=None, max_length=80)
    coverage_areas: list[str] | None = None
    image_url: str | None = None
    is_available: bool | None = None
    is_featured: bool | None = None

    @field_validator("image_url")
    @classmethod
    def validate_image_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _validate_http_url(value)


class ServiceOut(BaseModel):
    id: UUID
    name: str
    description: str
    pricing_type: PricingType = PricingType.FIXED
    pricing_model: PricingModel = PricingModel.FIXED_PRICE
    price_mad: float | None
    price_min_mad: float | None = None
    price_max_mad: float | None = None
    price_negotiable: bool = False
    category_slug: str = ""
    coverage_areas: list = Field(default_factory=list)
    image_url: str
    is_available: bool
    is_featured: bool = False

    model_config = {"from_attributes": True}


class OpeningHours(BaseModel):
    days: dict[str, bool] = Field(default_factory=dict)
    open: str = Field(default="09:00", max_length=5)
    close: str = Field(default="21:00", max_length=5)

    @field_validator("open", "close")
    @classmethod
    def validate_time(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) != 5 or cleaned[2] != ":":
            raise ValueError("Time must be HH:MM")
        hour_s, minute_s = cleaned.split(":")
        if not (hour_s.isdigit() and minute_s.isdigit()):
            raise ValueError("Time must be HH:MM")
        hour, minute = int(hour_s), int(minute_s)
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            raise ValueError("Time must be a valid clock time")
        return f"{hour:02d}:{minute:02d}"


class SellerCreate(BaseModel):
    business_name: str = Field(min_length=2, max_length=160)
    description: str = ""
    address: str = Field(min_length=5, max_length=255)
    city: str = Field(min_length=2, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    phone: str = ""
    cover_image_url: str = ""
    logo_image_url: str = ""
    opening_hours: OpeningHours | None = None
    website_url: str = Field(default="", max_length=255)
    instagram_url: str = Field(default="", max_length=255)
    facebook_url: str = Field(default="", max_length=255)
    tiktok_url: str = Field(default="", max_length=255)
    whatsapp_number: str = Field(default="", max_length=32)
    payment_methods: list[str] = Field(default_factory=lambda: ["cash"])
    delivery_methods: list[str] = Field(default_factory=lambda: ["in_store"])
    service_areas: list[str] = Field(default_factory=list)
    category_ids: list[UUID] = Field(default_factory=list)

    @field_validator("city")
    @classmethod
    def launch_city_only(cls, value: str) -> str:
        from app.config import settings

        cleaned = value.strip()
        for city in settings.default_cities:
            if city.casefold() == cleaned.casefold():
                return city
        raise ValueError(
            f"MarGem currently supports {', '.join(settings.default_cities)} only"
        )


class SellerUpdate(BaseModel):
    business_name: str | None = Field(default=None, min_length=2, max_length=160)
    description: str | None = None
    address: str | None = Field(default=None, min_length=5, max_length=255)
    city: str | None = Field(default=None, min_length=2, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    phone: str | None = None
    cover_image_url: str | None = None
    logo_image_url: str | None = None
    opening_hours: OpeningHours | None = None
    website_url: str | None = Field(default=None, max_length=255)
    instagram_url: str | None = Field(default=None, max_length=255)
    facebook_url: str | None = Field(default=None, max_length=255)
    tiktok_url: str | None = Field(default=None, max_length=255)
    whatsapp_number: str | None = Field(default=None, max_length=32)
    payment_methods: list[str] | None = None
    delivery_methods: list[str] | None = None
    service_areas: list[str] | None = None
    category_ids: list[UUID] | None = None
    is_active: bool | None = None

    @field_validator("city")
    @classmethod
    def launch_city_only(cls, value: str | None) -> str | None:
        if value is None:
            return None
        from app.config import settings

        cleaned = value.strip()
        for city in settings.default_cities:
            if city.casefold() == cleaned.casefold():
                return city
        raise ValueError(
            f"MarGem currently supports {', '.join(settings.default_cities)} only"
        )


class SellerSummary(BaseModel):
    id: UUID
    business_name: str
    description: str
    city: str
    latitude: float
    longitude: float
    cover_image_url: str
    logo_image_url: str = ""
    achievement_stars: int
    average_rating: float
    review_count: int
    avg_product_quality: float = 0.0
    avg_customer_service: float = 0.0
    avg_communication: float = 0.0
    avg_trustworthiness: float = 0.0
    golden_crowns: int = 0
    is_premium: bool = False
    verification_status: str = "unverified"
    avg_response_minutes: int = 0
    categories: list[CategoryOut]
    distance_km: float | None = None

    model_config = {"from_attributes": True}

    @field_validator("verification_status", mode="before")
    @classmethod
    def coerce_verification(cls, value):
        return value.value if hasattr(value, "value") else value


class SellerDetail(SellerSummary):
    address: str
    phone: str
    opening_hours: dict = Field(default_factory=dict)
    website_url: str = ""
    instagram_url: str = ""
    facebook_url: str = ""
    tiktok_url: str = ""
    whatsapp_number: str = ""
    payment_methods: list = Field(default_factory=list)
    delivery_methods: list = Field(default_factory=list)
    service_areas: list = Field(default_factory=list)
    profile_view_count: int = 0
    inquiry_count: int = 0
    favorite_count: int = 0
    contact_click_count: int = 0
    follower_count: int = 0
    created_at: datetime | None = None
    products: list[ProductOut]
    services: list[ServiceOut]


class SellerDashboardStats(BaseModel):
    seller_id: UUID
    business_name: str
    profile_view_count: int
    product_count: int
    available_product_count: int
    service_count: int
    review_count: int
    average_rating: float
    achievement_stars: int
    golden_crowns: int = 0
    recent_review_count: int
    inquiry_count: int = 0
    favorite_count: int = 0
    contact_click_count: int = 0
    avg_response_minutes: int = 0
    is_premium: bool = False
    verification_status: str = "unverified"
    is_active: bool


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def strong_password(cls, value: str) -> str:
        validate_password_strength(value)
        return value


class MapPin(BaseModel):
    id: UUID
    business_name: str
    latitude: float
    longitude: float
    achievement_stars: int
    golden_crowns: int = 0
    average_rating: float
    category_slugs: list[str]


class ReviewCreate(BaseModel):
    product_quality: int = Field(ge=1, le=5)
    customer_service: int = Field(ge=1, le=5)
    communication: int = Field(ge=1, le=5)
    trustworthiness: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)

    @field_validator(
        "product_quality",
        "customer_service",
        "communication",
        "trustworthiness",
    )
    @classmethod
    def validate_category_rating(cls, value: int) -> int:
        if not 1 <= value <= 5:
            raise ValueError("Rating must be between 1 and 5")
        return value


class ReviewOut(BaseModel):
    id: UUID
    rating: int
    overall_rating: float
    product_quality: int
    customer_service: int
    communication: int
    trustworthiness: int
    comment: str
    buyer_display_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ReviewEligibilityOut(BaseModel):
    can_review: bool
    reason: str
    has_reviewed: bool = False


class WarningZoneOut(BaseModel):
    id: UUID
    name: str
    description: str
    city: str
    latitude: float
    longitude: float
    radius_meters: float

    model_config = {"from_attributes": True}


class PresignRequest(BaseModel):
    filename: str
    content_type: str = "image/jpeg"


class PresignResponse(BaseModel):
    upload_url: str
    public_url: str
