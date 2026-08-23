"""Provider-agnostic billing helpers for Dribex service revenue."""

from __future__ import annotations

from app.config import settings


def billing_self_serve_enabled() -> bool:
    """Whether users can self-serve subscribe or buy advertising packages."""
    if settings.payment_provider == "none":
        return False
    if settings.app_env in {"production", "prod", "staging"}:
        return settings.payment_provider == "naps" and settings.naps_configured
    if settings.payment_provider == "naps" and settings.naps_configured:
        return True
    return settings.payment_provider == "manual" and settings.effective_allow_manual_billing


def manual_billing_allowed() -> bool:
    return settings.payment_provider == "manual" and settings.effective_allow_manual_billing


def production_payment_provider_name() -> str:
    return "naps"
