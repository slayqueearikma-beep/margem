import json
import logging
from typing import Annotated, Any

from pydantic import BeforeValidator, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

logger = logging.getLogger("margem.config")

_STRICT_ENVS = frozenset({"production", "prod", "staging", "preprod", "preview"})


def _normalize_host(host: str) -> str:
    """Starlette TrustedHost compares hostname without port."""
    value = host.strip().strip('"').strip("'")
    if "://" in value:
        value = value.split("://", 1)[1]
    return value.split("/")[0].split(":")[0]


def _is_loopback_or_private_url(url: str) -> bool:
    """True for localhost / RFC1918 LAN hosts (home-server HTTP allowed)."""
    from ipaddress import ip_address
    from urllib.parse import urlparse

    host = (urlparse(url).hostname or "").lower()
    if not host or host == "localhost":
        return True
    try:
        addr = ip_address(host)
    except ValueError:
        return False
    return bool(addr.is_loopback or addr.is_private)


def _is_loopback_or_private_host(host: str) -> bool:
    """True for localhost, loopback, or RFC1918 hostnames (not full URLs)."""
    from ipaddress import ip_address

    clean = _normalize_host(host).lower()
    if clean in {"localhost", "127.0.0.1", "0.0.0.0", "::1"}:
        return True
    try:
        addr = ip_address(clean)
    except ValueError:
        return False
    return bool(addr.is_loopback or addr.is_private)


def _cors_origin_is_dev_only(origin: str) -> bool:
    """True when a CORS origin points at localhost or a private/LAN address."""
    from urllib.parse import urlparse

    parsed = urlparse(origin.strip())
    host = (parsed.hostname or "").lower()
    if not host:
        return True
    return _is_loopback_or_private_host(host)


def _parse_string_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        stripped = value.strip().strip("'").strip('"')
        if not stripped:
            return []
        if stripped.startswith("["):
            try:
                parsed = json.loads(stripped)
                if isinstance(parsed, list):
                    return [str(item).strip() for item in parsed if str(item).strip()]
            except json.JSONDecodeError:
                # Docker/.env often mangles JSON quotes — fall back to loose parse.
                inner = stripped.strip("[]")
                return [
                    item.strip().strip('"').strip("'")
                    for item in inner.split(",")
                    if item.strip()
                ]
        return [
            item.strip().strip('"').strip("'")
            for item in stripped.split(",")
            if item.strip()
        ]
    return value


# NoDecode prevents pydantic-settings from JSON-parsing env vars before our validator.
CommaSeparatedList = Annotated[list[str], NoDecode, BeforeValidator(_parse_string_list)]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Dribex API"
    app_env: str = "development"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    auth_dev_bypass: bool = False
    # When false, non-production hosts cannot activate premium without NAPS/manual billing.
    allow_manual_billing: bool = False
    # In production, verified email is required before creating a storefront,
    # messaging users, or creating reputation signals.
    require_verified_email: bool = True
    firebase_credentials_path: str = ""
    jwt_secret_key: str = "change-this-secret-in-production-use-key-vault"
    # Separate key limits the blast radius of a JWT signing-key compromise.
    # Defaults to the JWT key only in development for backwards compatibility.
    upload_token_secret: str = ""
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "margem-api"
    jwt_audience: str = "margem-mobile"
    jwt_access_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 7
    bcrypt_rounds: int = 12
    login_lockout_threshold: int = 5
    staff_mfa_required: bool = True
    mfa_encryption_key: str = ""

    azure_storage_connection_string: str = ""
    azure_storage_container: str = "margem-media"
    # Active provider: selfhosted (MinIO), azure, or local (dev/tests).
    # STORAGE_BACKEND is deprecated — kept for backward compatibility only.
    storage_provider: str = ""
    storage_backend: str = "azure"
    local_media_root: str = "./data/media"
    minio_endpoint: str = ""
    minio_access_key: str = ""
    minio_secret_key: str = ""
    minio_bucket: str = "margem-media"
    minio_bucket_profiles: str = "dribex-profiles"
    minio_bucket_products: str = "dribex-products"
    minio_bucket_listings: str = "dribex-listings"
    minio_bucket_private: str = "dribex-private"
    minio_public_url: str = ""
    minio_region: str = ""
    max_upload_bytes: int = 8_388_608
    max_video_upload_bytes: int = 52_428_800

    cors_origins: CommaSeparatedList = ["http://localhost:3000"]
    allowed_hosts: CommaSeparatedList = ["*"]

    rate_limit: str = "300/minute"
    auth_rate_limit: str = "30/minute"
    password_reset_request_rate_limit: str = "5/minute"
    password_reset_confirm_rate_limit: str = "10/minute"
    password_reset_expire_hours: int = 2
    signup_otp_verify_rate_limit: str = "5/minute"
    max_request_body_bytes: int = 1_048_576
    redis_url: str = ""
    allow_insecure_email_fallback: bool = False
    # Number of trusted reverse-proxy hops that append X-Forwarded-For (0 = direct).
    trusted_proxy_hops: int = 0
    upload_allowed_hosts: CommaSeparatedList = []
    # When set, /admin/* paths require client IP in these ranges (CIDR ok). Loopback always allowed.
    admin_ip_allowlist: CommaSeparatedList = []

    # Brevo — official transactional email provider (API key must never be committed).
    brevo_api_key: str = ""
    brevo_sender_email: str = ""
    brevo_sender_name: str = "Dribex"
    email_provider: str = ""
    email_reply_to: str = ""
    email_send_timeout_seconds: int = 20
    email_max_retries: int = 2
    email_retry_delay_seconds: float = 0.75
    public_app_url: str = "https://dribex.ma"
    public_api_url: str = "http://localhost:8000"
    # Optional path to admin-dashboard static files (Docker: /admin-dashboard).
    admin_dashboard_dir: str = ""
    # When false, do not serve /admin static files from the API (use separate admin container).
    serve_embedded_admin: bool = True
    # Require MFA for staff/admin API access outside dev (home server: set true in .env.home).
    admin_require_staff_mfa: bool = False

    # Production URLs
    qr_public_base_url: str = "https://qr.dribex.ma"
    sentry_dsn: str = ""

    free_seller_combined_listing_limit: int = 5
    driver_pro_combined_listing_limit: int = 20
    buyer_plus_plan_code: str = "buyer_premium"
    driver_pro_plan_code: str = "seller_pro"

    default_cities: list[str] = [
        "Casablanca",
    ]

    # Platform billing only — never buyer↔seller marketplace checkout.
    payment_provider: str = "none"
    payment_currency: str = "mad"

    # Launch monetization flags — advertising-first production model.
    payments_enabled: bool = False
    subscriptions_enabled: bool = False
    ads_enabled: bool = True
    rewarded_ads_enabled: bool = False
    rewarded_ad_signing_secret: str = ""

    # NAPS ePay — preserved for future paid subscriptions (inactive when payments_enabled=false).
    naps_environment: str = "sandbox"
    naps_merchant_id: str = ""
    naps_api_key: str = ""
    naps_secret_key: str = ""
    naps_webhook_secret: str = ""
    naps_api_key_header: str = "X-API-Key"
    naps_epay_payment_init_url: str = ""
    naps_epay_payment_status_url: str = ""
    naps_request_signing_enabled: bool = True
    naps_response_payment_id_path: str = "payment_id"
    naps_response_redirect_url_path: str = "redirect_url"
    naps_response_status_path: str = "status"
    naps_response_amount_path: str = "amount"
    naps_response_currency_path: str = "currency"
    naps_webhook_event_id_field: str = "event_id"
    naps_webhook_status_field: str = "status"
    naps_webhook_payment_id_field: str = "payment_id"
    naps_webhook_amount_field: str = "amount"
    naps_webhook_currency_field: str = "currency"
    naps_webhook_signature_header: str = "X-NAPS-Signature"
    naps_webhook_success_statuses: CommaSeparatedList = ["success", "paid", "completed"]
    naps_extra_request_fields_json: str = "{}"

    @field_validator("storage_provider", mode="before")
    @classmethod
    def normalize_storage_provider(cls, value: Any) -> str:
        if value is None or value == "":
            return ""
        cleaned = str(value).strip().lower()
        aliases = {
            "minio": "selfhosted",
            "s3": "selfhosted",
            "self-hosted": "selfhosted",
            "self_hosted": "selfhosted",
        }
        cleaned = aliases.get(cleaned, cleaned)
        if cleaned not in {"selfhosted", "azure", "local"}:
            raise ValueError("STORAGE_PROVIDER must be 'selfhosted', 'azure', or 'local'")
        return cleaned

    @field_validator("payment_provider", mode="before")
    @classmethod
    def normalize_payment_provider(cls, value: Any) -> str:
        if value is None or value == "":
            return "manual"
        cleaned = str(value).strip().lower()
        if cleaned not in {"manual", "naps", "none"}:
            raise ValueError("PAYMENT_PROVIDER must be 'manual', 'naps', or 'none'")
        return cleaned

    @field_validator("naps_environment", mode="before")
    @classmethod
    def normalize_naps_environment(cls, value: Any) -> str:
        if value is None or value == "":
            return "sandbox"
        cleaned = str(value).strip().lower()
        if cleaned not in {"sandbox", "production"}:
            raise ValueError("NAPS_ENVIRONMENT must be 'sandbox' or 'production'")
        return cleaned

    @field_validator("storage_backend", mode="before")
    @classmethod
    def normalize_storage_backend(cls, value: Any) -> str:
        if value is None or value == "":
            return "azure"
        cleaned = str(value).strip().lower()
        if cleaned not in {"azure", "local", "minio"}:
            raise ValueError("STORAGE_BACKEND must be 'azure', 'local', or 'minio'")
        return cleaned

    @field_validator("email_provider", mode="before")
    @classmethod
    def normalize_email_provider(cls, value: Any) -> str:
        if value is None:
            return ""
        cleaned = str(value).strip().lower()
        if not cleaned:
            return ""
        if cleaned not in {"brevo", "log"}:
            raise ValueError("EMAIL_PROVIDER must be 'brevo' or 'log'")
        return cleaned

    @property
    def effective_email_provider(self) -> str:
        explicit = (self.email_provider or "").strip().lower()
        if explicit:
            return explicit
        if self.brevo_api_key.strip():
            return "brevo"
        if self.allow_insecure_email_fallback:
            return "log"
        return "brevo"

    @property
    def effective_from_header(self) -> str:
        address = self.brevo_sender_email.strip()
        name = self.brevo_sender_name.strip() or "Dribex"
        if address:
            return f"{name} <{address}>"
        return "Dribex <noreply@dribex.ma>"

    @property
    def effective_email_reply_to(self) -> str:
        return self.email_reply_to.strip()

    @property
    def effective_storage_provider(self) -> str:
        """Resolve the single active storage provider at runtime."""
        explicit = (self.storage_provider or "").strip().lower()
        if explicit:
            return explicit
        if self.storage_backend == "minio":
            return "selfhosted"
        if self.storage_backend == "local":
            return "local"
        return "azure"

    @field_validator("azure_storage_connection_string", "azure_storage_container", "local_media_root", mode="before")
    @classmethod
    def strip_secrets(cls, value: Any) -> Any:
        if isinstance(value, str):
            return value.strip().strip('"').strip("'")
        return value

    @field_validator("allowed_hosts", mode="after")
    @classmethod
    def normalize_allowed_hosts(cls, value: list[str]) -> list[str]:
        if value == ["*"] or "*" in value:
            return ["*"]
        normalized: list[str] = []
        for host in value:
            clean = _normalize_host(host)
            if clean and clean not in normalized:
                normalized.append(clean)
        return normalized

    @staticmethod
    def _looks_like_placeholder(value: str) -> bool:
        upper = value.upper()
        return any(
            marker in upper
            for marker in ("CHANGE_ME", "CHANGE-THIS-SECRET", "CHANGE-IN-PRODUCTION")
        )

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if not self.mfa_encryption_key:
            object.__setattr__(self, "mfa_encryption_key", self.jwt_secret_key)
        if not self.rewarded_ad_signing_secret:
            object.__setattr__(self, "rewarded_ad_signing_secret", self.upload_token_secret or self.jwt_secret_key)
        if not self.payments_enabled:
            object.__setattr__(self, "payment_provider", "none")
        elif self.payment_provider == "none":
            object.__setattr__(self, "payment_provider", "manual")
        if self.app_env != "production" and self.naps_environment == "production":
            raise ValueError(
                "Refusing to start: non-production APP_ENV with NAPS_ENVIRONMENT=production. "
                "Set NAPS_ENVIRONMENT=sandbox."
            )
        if self.app_env in _STRICT_ENVS:
            if self.auth_dev_bypass:
                raise ValueError("AUTH_DEV_BYPASS must be false outside local development")
            if self.debug:
                raise ValueError("DEBUG must be false in production")
            if len(self.jwt_secret_key) < 32:
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production")
            # Reject the documented default even when it already meets length checks.
            if self.jwt_secret_key.startswith("change-this-secret") or self._looks_like_placeholder(
                self.jwt_secret_key
            ):
                raise ValueError("JWT_SECRET_KEY must be rotated away from placeholder values in production")
            if self._looks_like_placeholder(self.upload_token_secret):
                raise ValueError("UPLOAD_TOKEN_SECRET must not use placeholder values in production")
            if self._looks_like_placeholder(self.mfa_encryption_key):
                raise ValueError("MFA_ENCRYPTION_KEY must not use placeholder values in production")
            if len(self.mfa_encryption_key) < 32:
                raise ValueError("MFA_ENCRYPTION_KEY must be at least 32 characters in production")
            if self.mfa_encryption_key == self.jwt_secret_key:
                raise ValueError("MFA_ENCRYPTION_KEY must differ from JWT_SECRET_KEY in production")
            provider = self.effective_storage_provider
            if provider == "local":
                if not self.upload_token_secret or len(self.upload_token_secret) < 32:
                    raise ValueError("UPLOAD_TOKEN_SECRET must be at least 32 characters in production")
                if self.upload_token_secret == self.jwt_secret_key:
                    raise ValueError("UPLOAD_TOKEN_SECRET must differ from JWT_SECRET_KEY in production")
            if "*" in self.cors_origins:
                raise ValueError("CORS_ORIGINS must not include '*' in production")
            if "*" in self.allowed_hosts:
                raise ValueError("ALLOWED_HOSTS must not include '*' in production")
            if provider == "azure" and not self.azure_storage_connection_string:
                raise ValueError(
                    "AZURE_STORAGE_CONNECTION_STRING is required in production when STORAGE_PROVIDER=azure"
                )
            if provider == "selfhosted":
                if not self.minio_endpoint or not self.minio_access_key or not self.minio_secret_key:
                    raise ValueError(
                        "MINIO_ENDPOINT, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY are required "
                        "when STORAGE_PROVIDER=selfhosted"
                    )
                if not self.public_api_url:
                    raise ValueError("PUBLIC_API_URL is required in production when STORAGE_PROVIDER=selfhosted")
            if provider == "local" and not self.public_api_url:
                raise ValueError("PUBLIC_API_URL is required in production when STORAGE_PROVIDER=local")
            if not self.allow_insecure_email_fallback:
                if not self.brevo_api_key.strip():
                    raise ValueError(
                        "BREVO_API_KEY is required in staging/production "
                        "(set ALLOW_INSECURE_EMAIL_FALLBACK=true only for emergency break-glass)"
                    )
                if not self.brevo_sender_email.strip():
                    raise ValueError("BREVO_SENDER_EMAIL is required in staging/production")
            elif not self.brevo_api_key.strip():
                logger.warning(
                    "ALLOW_INSECURE_EMAIL_FALLBACK enabled — password reset and verification "
                    "emails will only be logged, not delivered"
                )
            if self.effective_email_provider == "brevo" and not self.allow_insecure_email_fallback:
                if not self.brevo_sender_name.strip():
                    raise ValueError("BREVO_SENDER_NAME must not be empty when using Brevo")
            if self.public_api_url.startswith("http://") and not _is_loopback_or_private_url(
                self.public_api_url
            ):
                raise ValueError(
                    "PUBLIC_API_URL must use HTTPS in production "
                    "(http is only allowed for localhost / private LAN IPs)"
                )
            if self.public_app_url.startswith("http://") and not _is_loopback_or_private_url(
                self.public_app_url
            ):
                raise ValueError(
                    "PUBLIC_APP_URL must use HTTPS in production "
                    "(http is only allowed for localhost / private LAN IPs)"
                )
            if self.app_env in {"production", "prod"} and not self.admin_ip_allowlist:
                raise ValueError(
                    "ADMIN_IP_ALLOWLIST is required in production — "
                    "admin APIs must not be reachable from any IP"
                )
            if self.payments_enabled:
                if self.payment_provider == "naps" and self.app_env in {"production", "prod"}:
                    missing = self.naps_missing_config_fields()
                    if missing:
                        raise ValueError(
                            "NAPS ePay configuration incomplete for production: "
                            + ", ".join(missing)
                        )
                if self.payment_provider == "manual" and self.app_env in {"production", "prod"}:
                    raise ValueError(
                        "PAYMENT_PROVIDER=manual is not allowed in production. "
                        "Use PAYMENT_PROVIDER=naps or set PAYMENTS_ENABLED=false."
                    )
            if self.rewarded_ads_enabled:
                secret = self.rewarded_ad_signing_secret.strip()
                if len(secret) < 32:
                    raise ValueError("REWARDED_AD_SIGNING_SECRET must be at least 32 characters when rewarded ads are enabled")
                if self._looks_like_placeholder(secret):
                    raise ValueError("REWARDED_AD_SIGNING_SECRET must not use placeholder values in production")
            for host in self.allowed_hosts:
                if _is_loopback_or_private_host(host):
                    raise ValueError(
                        f"ALLOWED_HOSTS must not include development-only host '{host}' "
                        f"when APP_ENV={self.app_env}"
                    )
            for origin in self.cors_origins:
                if _cors_origin_is_dev_only(origin):
                    raise ValueError(
                        f"CORS_ORIGINS must not include development-only origin '{origin}' "
                        f"when APP_ENV={self.app_env}"
                    )
            if self.app_env in {"production", "prod"} and not self.admin_require_staff_mfa:
                raise ValueError("ADMIN_REQUIRE_STAFF_MFA must be true in production")
            if not self.redis_url.strip():
                logger.warning(
                    "REDIS_URL is not configured — rate limits are per-process only and will "
                    "not share state across API replicas"
                )
        if self.app_env in {"development", "dev", "test"} and "*" not in self.allowed_hosts:
            dev_hosts = list(self.allowed_hosts)
            for loopback in ("localhost", "127.0.0.1"):
                if loopback not in dev_hosts:
                    dev_hosts.append(loopback)
            object.__setattr__(self, "allowed_hosts", dev_hosts)
        if self.auth_dev_bypass and self.app_env not in {"development", "dev"}:
            raise ValueError("AUTH_DEV_BYPASS is only allowed when APP_ENV is development or dev")
        return self

    @property
    def effective_allow_manual_billing(self) -> bool:
        if self.allow_manual_billing:
            return True
        return self.app_env in {"development", "dev", "test"} and self.payment_provider == "manual"

    @property
    def naps_extra_request_fields(self) -> dict[str, Any]:
        import json

        raw = (self.naps_extra_request_fields_json or "{}").strip()
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}

    @property
    def naps_configured(self) -> bool:
        return not self.naps_missing_config_fields()

    def naps_missing_config_fields(self) -> list[str]:
        required = {
            "NAPS_MERCHANT_ID": self.naps_merchant_id.strip(),
            "NAPS_SECRET_KEY": self.naps_secret_key.strip(),
            "NAPS_EPAY_PAYMENT_INIT_URL": self.naps_epay_payment_init_url.strip(),
            "NAPS_WEBHOOK_SECRET": self.naps_webhook_secret.strip(),
        }
        if self.naps_environment == "production":
            required["NAPS_API_KEY"] = self.naps_api_key.strip()
        return [name for name, value in required.items() if not value]


settings = Settings()
logger.info(
    "allowed_hosts=%s cors_origins=%s app_env=%s",
    settings.allowed_hosts,
    settings.cors_origins,
    settings.app_env,
)
