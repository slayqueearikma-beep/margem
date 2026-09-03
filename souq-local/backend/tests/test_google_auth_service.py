"""Unit tests for Google auth helpers (no database required)."""

from __future__ import annotations

from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.services.google_auth import google_firebase_uid, verify_google_id_token


pytestmark = pytest.mark.no_db


def test_google_firebase_uid_prefixes_sub():
    assert google_firebase_uid("abc123") == "google-abc123"


def test_verify_google_id_token_rejects_when_unconfigured(monkeypatch):
    monkeypatch.setattr(
        "app.services.google_auth.settings.google_oauth_client_ids",
        [],
    )
    with pytest.raises(HTTPException) as exc:
        verify_google_id_token("token")
    assert exc.value.status_code == 503


def test_verify_google_id_token_validates_claims(monkeypatch):
    monkeypatch.setattr(
        "app.services.google_auth.settings.google_oauth_client_ids",
        ["test-client-id.apps.googleusercontent.com"],
    )

    def fake_verify(token, request, audience):
        assert token == "good-token"
        assert audience == "test-client-id.apps.googleusercontent.com"
        return {
            "iss": "accounts.google.com",
            "sub": "sub-42",
            "email": "user@example.com",
            "email_verified": True,
            "name": "Test User",
        }

    with patch("google.oauth2.id_token.verify_oauth2_token", fake_verify):
        identity = verify_google_id_token("good-token")

    assert identity.sub == "sub-42"
    assert identity.email == "user@example.com"
    assert identity.email_verified is True
    assert identity.display_name == "Test User"


def test_verify_google_id_token_rejects_unverified_email(monkeypatch):
    monkeypatch.setattr(
        "app.services.google_auth.settings.google_oauth_client_ids",
        ["test-client-id.apps.googleusercontent.com"],
    )

    def fake_verify(token, request, audience):
        return {
            "iss": "accounts.google.com",
            "sub": "sub-42",
            "email": "user@example.com",
            "email_verified": False,
        }

    with patch("google.oauth2.id_token.verify_oauth2_token", fake_verify):
        with pytest.raises(HTTPException) as exc:
            verify_google_id_token("good-token")
    assert exc.value.status_code == 401


def test_verify_google_id_token_rejects_invalid_issuer(monkeypatch):
    monkeypatch.setattr(
        "app.services.google_auth.settings.google_oauth_client_ids",
        ["test-client-id.apps.googleusercontent.com"],
    )

    def fake_verify(token, request, audience):
        return {
            "iss": "evil.example.com",
            "sub": "sub-42",
            "email": "user@example.com",
            "email_verified": True,
        }

    with patch("google.oauth2.id_token.verify_oauth2_token", fake_verify):
        with pytest.raises(HTTPException) as exc:
            verify_google_id_token("good-token")
    assert exc.value.status_code == 401
