#!/usr/bin/env python3
"""Validate .env.home before docker compose up — prints actionable fixes."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_PLACEHOLDER_MARKERS = ("CHANGE_ME", "change-this-secret", "change-in-production")


def _load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped:
            continue
        key, _, raw = stripped.partition("=")
        values[key.strip()] = raw.strip().strip('"').strip("'")
    return values


def _is_placeholder(value: str) -> bool:
    upper = value.upper()
    return any(marker.upper() in upper for marker in _PLACEHOLDER_MARKERS)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate MarGem home server environment")
    parser.add_argument(
        "env_file",
        nargs="?",
        default=str(Path(__file__).resolve().parents[2] / ".env.home"),
    )
    args = parser.parse_args()
    env_path = Path(args.env_file)
    if not env_path.is_file():
        print(f"ERROR: {env_path} not found. Copy env.home.example to .env.home first.")
        return 1

    raw = _load_env_file(env_path)
    errors: list[str] = []
    warnings: list[str] = []

    for key in ("POSTGRES_PASSWORD", "JWT_SECRET_KEY", "UPLOAD_TOKEN_SECRET", "MFA_ENCRYPTION_KEY"):
        value = raw.get(key, "")
        if not value:
            errors.append(f"{key} is empty")
        elif _is_placeholder(value):
            errors.append(f"{key} still uses a placeholder — generate with: openssl rand -hex 32")

    jwt = raw.get("JWT_SECRET_KEY", "")
    upload = raw.get("UPLOAD_TOKEN_SECRET", "")
    mfa = raw.get("MFA_ENCRYPTION_KEY", "")
    if jwt and upload and jwt == upload:
        errors.append("UPLOAD_TOKEN_SECRET must differ from JWT_SECRET_KEY")
    if jwt and mfa and jwt == mfa:
        errors.append("MFA_ENCRYPTION_KEY must differ from JWT_SECRET_KEY")

    hosts = raw.get("ALLOWED_HOSTS", "")
    public_api = raw.get("PUBLIC_API_URL", "")
    if public_api.startswith("http://"):
        from urllib.parse import urlparse

        host = urlparse(public_api).hostname or ""
        if host and host not in ("localhost", "127.0.0.1") and host not in hosts:
            warnings.append(
                f"ALLOWED_HOSTS should include PUBLIC_API_URL host '{host}' "
                "(phones may get 400 Invalid host header)"
            )

    smtp = raw.get("SMTP_HOST", "")
    insecure = raw.get("ALLOW_INSECURE_EMAIL_FALLBACK", "false").lower() == "true"
    if not smtp and not insecure:
        errors.append(
            "SMTP_HOST is empty and ALLOW_INSECURE_EMAIL_FALLBACK=false — "
            "API will not start in production. For LAN home without SMTP, set "
            "ALLOW_INSECURE_EMAIL_FALLBACK=true"
        )
    if insecure and not smtp:
        warnings.append(
            "ALLOW_INSECURE_EMAIL_FALLBACK=true — verification emails will be logged, not delivered"
        )

    cors = raw.get("CORS_ORIGINS", "")
    if public_api and public_api not in cors:
        warnings.append(f"CORS_ORIGINS should include PUBLIC_API_URL ({public_api}) for the mobile app")

    admin_port = raw.get("ADMIN_PORT", "8080").strip() or "8080"
    if public_api:
        from urllib.parse import urlparse

        parsed = urlparse(public_api)
        if parsed.hostname:
            admin_origin = f"{parsed.scheme}://{parsed.hostname}:{admin_port}"
            if admin_origin not in cors:
                warnings.append(
                    f"CORS_ORIGINS should include admin dashboard origin ({admin_origin})"
                )

    if not raw.get("ADMIN_IP_ALLOWLIST", "").strip():
        errors.append(
            "ADMIN_IP_ALLOWLIST is empty — set private LAN ranges "
            "(see env.home.example) before exposing the API"
        )


    # Pydantic Settings validation (full cross-field rules).
    try:
        from app.config import Settings

        Settings(_env_file=str(env_path))
    except Exception as exc:  # noqa: BLE001
        errors.append(f"Settings validation failed: {exc}")

    if warnings:
        print("Warnings:")
        for item in warnings:
            print(f"  • {item}")
        print()

    if errors:
        print("Errors (fix before starting):")
        for item in errors:
            print(f"  ✗ {item}")
        return 1

    print(f"OK: {env_path} passed validation.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
