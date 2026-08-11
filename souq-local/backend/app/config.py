import json
import logging
from typing import Annotated, Any

from pydantic import BeforeValidator, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

logger = logging.getLogger("margem.config")


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

    app_name: str = "MarGem API"
    app_env: str = "development"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    auth_dev_bypass: bool = False
    # When false, non-production hosts cannot activate premium without Stripe.
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
    # azure = Blob SAS; local = API disk; minio = S3-compatible on-prem object store.
    storage_backend: str = "azure"
    local_media_root: str = "./data/media"
    minio_endpoint: str = ""
    minio_access_key: str = ""
    minio_secret_key: str = ""
    minio_bucket: str = "margem-media"
    minio_public_url: str = ""
    minio_region: str = ""
    max_upload_bytes: int = 8_388_608

    cors_origins: CommaSeparatedList = ["http://localhost:3000"]
    allowed_hosts: CommaSeparatedList = ["*"]

    rate_limit: str = "300/minute"
    auth_rate_limit: str = "30/minute"
    signup_otp_verify_rate_limit: str = "5/minute"
    max_request_body_bytes: int = 1_048_576
    redis_url: str = ""
    allow_insecure_email_fallback: bool = False
    # Number of trusted reverse-proxy hops that append X-Forwarded-For (0 = direct).
    trusted_proxy_hops: int = 0
    upload_allowed_hosts: CommaSeparatedList = []
    # When set, /admin/* paths require client IP in these ranges (CIDR ok). Loopback always allowed.
    admin_ip_allowlist: CommaSeparatedList = []

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    smtp_from: str = "MarGem <noreply@margem.ma>"
    smtp_use_tls: bool = True
    public_app_url: str = "https://margem.ma"
    public_api_url: str = "http://localhost:8000"
    # Optional path to admin-dashboard static files (Docker: /admin-dashboard).
    admin_dashboard_dir: str = ""
    # When false, do not serve /admin static files from the API (use separate admin container).
    serve_embedded_admin: bool = True
    # Require MFA for staff/admin API access outside dev (home server: set true in .env.home).
    admin_require_staff_mfa: bool = False

    default_cities: list[str] = [
        "Casablanca",
    ]

    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_currency: str = "mad"

    @field_validator("storage_backend", mode="before")
    @classmethod
    def normalize_storage_backend(cls, value: Any) -> str:
        if value is None or value == "":
            return "azure"
        cleaned = str(value).strip().lower()
        if cleaned not in {"azure", "local", "minio"}:
            raise ValueError("STORAGE_BACKEND must be 'azure', 'local', or 'minio'")
        return cleaned

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
        for loopback in ("localhost", "127.0.0.1"):
            if loopback not in normalized:
                normalized.append(loopback)
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
        if self.app_env in {"production", "prod"}:
            if self.debug:
                raise ValueError("DEBUG must be false in production")
            if self.auth_dev_bypass:
                raise ValueError("AUTH_DEV_BYPASS must be false in production")
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
            if self.storage_backend == "local":
                if not self.upload_token_secret or len(self.upload_token_secret) < 32:
                    raise ValueError("UPLOAD_TOKEN_SECRET must be at least 32 characters in production")
                if self.upload_token_secret == self.jwt_secret_key:
                    raise ValueError("UPLOAD_TOKEN_SECRET must differ from JWT_SECRET_KEY in production")
            if "*" in self.cors_origins:
                raise ValueError("CORS_ORIGINS must not include '*' in production")
            if "*" in self.allowed_hosts:
                raise ValueError("ALLOWED_HOSTS must not include '*' in production")
            if self.storage_backend == "azure" and not self.azure_storage_connection_string:
                raise ValueError("AZURE_STORAGE_CONNECTION_STRING is required in production when STORAGE_BACKEND=azure")
            if self.storage_backend == "minio":
                if not self.minio_endpoint or not self.minio_access_key or not self.minio_secret_key:
                    raise ValueError("MINIO_ENDPOINT, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY are required when STORAGE_BACKEND=minio")
                if not self.minio_public_url:
                    raise ValueError("MINIO_PUBLIC_URL is required when STORAGE_BACKEND=minio")
            if self.storage_backend == "local" and not self.public_api_url:
                raise ValueError("PUBLIC_API_URL is required in production when STORAGE_BACKEND=local")
            if not self.smtp_host and not self.allow_insecure_email_fallback:
                raise ValueError(
                    "SMTP_HOST is required in production (set ALLOW_INSECURE_EMAIL_FALLBACK=true "
                    "only for emergency break-glass when outbound mail is unavailable)"
                )
            if not self.smtp_host and self.allow_insecure_email_fallback:
                logger.warning(
                    "ALLOW_INSECURE_EMAIL_FALLBACK enabled — password reset and verification "
                    "emails will only be logged, not delivered"
                )
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
        return self


settings = Settings()
logger.info(
    "allowed_hosts=%s cors_origins=%s app_env=%s",
    settings.allowed_hosts,
    settings.cors_origins,
    settings.app_env,
)
