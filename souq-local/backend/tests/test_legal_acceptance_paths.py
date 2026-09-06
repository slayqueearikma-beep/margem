"""Regression tests for auth.py legal acceptance path rules."""

from app.auth import _requires_legal_acceptance


def test_export_requires_legal_acceptance():
    assert _requires_legal_acceptance("/auth/me/export") is True


def test_me_status_exempt_from_legal_acceptance():
    assert _requires_legal_acceptance("/auth/me") is False
    assert _requires_legal_acceptance("/legal/accept/status") is False


def test_verify_email_exempt_from_legal_acceptance():
    assert _requires_legal_acceptance("/auth/verify-email/confirm") is False


def test_discovery_requires_legal_acceptance():
    assert _requires_legal_acceptance("/favorites") is True
