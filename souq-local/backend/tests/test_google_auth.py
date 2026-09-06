"""Tests for Google Sign-In authentication and account linking."""

from __future__ import annotations

from datetime import UTC, datetime
from unittest.mock import patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.models import User
from app.services.google_auth import GoogleIdentity
from tests.auth_helpers import register_test_user


def _identity(
    *,
    sub: str = "google-sub-123",
    email: str = "google.user@example.com",
    name: str = "Google User",
) -> GoogleIdentity:
    return GoogleIdentity(
        sub=sub,
        email=email,
        email_verified=True,
        display_name=name,
    )


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_auth_creates_new_user():
    transport = ASGITransport(app=app)
    identity = _identity()
    with patch("app.routers.auth.verify_google_id_token", return_value=identity):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/auth/google",
                json={"id_token": "valid-google-token", "account_type": "buyer"},
            )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["user"]["email"] == identity.email
    assert body["user"]["email_verified"] is True
    assert body["link_required"] is False


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_auth_existing_google_user_logs_in():
    transport = ASGITransport(app=app)
    identity = _identity(sub="stable-sub", email="stable@example.com")
    with patch("app.routers.auth.verify_google_id_token", return_value=identity):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            first = await client.post(
                "/auth/google",
                json={"id_token": "valid-google-token"},
            )
            assert first.status_code == 200
            second = await client.post(
                "/auth/google",
                json={"id_token": "valid-google-token"},
            )
    assert second.status_code == 200
    assert second.json()["user"]["email"] == "stable@example.com"


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_auth_requires_link_for_password_user():
    transport = ASGITransport(app=app)
    email = "existing@example.com"
    password = "SecurePass1"
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await register_test_user(
            client,
            email=email,
            password=password,
            account_type="buyer",
            display_name="Existing",
        )
        identity = _identity(email=email)
        with patch("app.routers.auth.verify_google_id_token", return_value=identity):
            response = await client.post(
                "/auth/google",
                json={"id_token": "valid-google-token"},
            )
    assert response.status_code == 200
    body = response.json()
    assert body["link_required"] is True
    assert body["email_hint"]
    assert not body["access_token"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_link_connects_existing_password_account():
    transport = ASGITransport(app=app)
    email = "linkme@example.com"
    password = "SecurePass1"
    identity = _identity(email=email, sub="link-sub-1")
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await register_test_user(
            client,
            email=email,
            password=password,
            account_type="buyer",
            display_name="Link Me",
        )
        with patch("app.routers.auth.verify_google_id_token", return_value=identity):
            link = await client.post(
                "/auth/google/link",
                json={"id_token": "valid-google-token", "password": password},
            )
            assert link.status_code == 200, link.text
            relogin = await client.post(
                "/auth/google",
                json={"id_token": "valid-google-token"},
            )
    assert relogin.status_code == 200
    assert relogin.json()["access_token"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_link_rejects_wrong_password():
    transport = ASGITransport(app=app)
    email = "wrongpass@example.com"
    password = "SecurePass1"
    identity = _identity(email=email)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await register_test_user(
            client,
            email=email,
            password=password,
            account_type="buyer",
            display_name="Wrong Pass",
        )
        with patch("app.routers.auth.verify_google_id_token", return_value=identity):
            response = await client.post(
                "/auth/google/link",
                json={"id_token": "valid-google-token", "password": "WrongPass9"},
            )
    assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.usefixtures("prepare_database")
async def test_google_auth_rejects_invalid_token():
    transport = ASGITransport(app=app)
    from fastapi import HTTPException

    with patch(
        "app.routers.auth.verify_google_id_token",
        side_effect=HTTPException(status_code=401, detail="Invalid Google credential"),
    ):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/auth/google",
                json={"id_token": "bad-token"},
            )
    assert response.status_code == 401
