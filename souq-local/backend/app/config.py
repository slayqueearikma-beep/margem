import json
from typing import Any

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = "MarGem API"
    app_env: str = "development"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local"

    auth_dev_bypass: bool = False
    firebase_credentials_path: str = ""
    jwt_secret_key: str = "change-this-secret-in-production-use-key-vault"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7

    azure_storage_connection_string: str = ""
    azure_storage_container: str = "margem-media"

    cors_origins: list[str] = ["http://localhost:3000"]
    allowed_hosts: list[str] = ["*"]

    rate_limit: str = "120/minute"
    auth_rate_limit: str = "10/minute"

    default_cities: list[str] = [
        "Casablanca",
        "Rabat",
        "Marrakech",
        "Fes",
        "Tangier",
        "Agadir",
        "Meknes",
        "Oujda",
    ]

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: Any) -> list[str]:
        if isinstance(value, str):
            stripped = value.strip()
            if stripped.startswith("["):
                return json.loads(stripped)
            return [origin.strip() for origin in stripped.split(",") if origin.strip()]
        return value

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.app_env in {"production", "prod"}:
            if self.auth_dev_bypass:
                raise ValueError("AUTH_DEV_BYPASS must be false in production")
            if len(self.jwt_secret_key) < 32:
                raise ValueError("JWT_SECRET_KEY must be at least 32 characters in production")
            if "*" in self.cors_origins:
                raise ValueError("CORS_ORIGINS must not include '*' in production")
        return self


settings = Settings()
