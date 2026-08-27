"""Password reset security: enumeration resistance, token hygiene, sessions, rate limits."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from limits import parse
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import AuthToken, User, UserStatus
from app.routers.auth import GENERIC_PASSWORD_RESET_MESSAGE, _hash_token
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture(autouse=True)
def reset_password_reset_rate_limits():
    from app.limiter import limiter

    limiter.reset()
    yield
    limiter.reset()


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, email: str | None = None) -> dict:
    address = email or f"reset-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    body = await register_test_user(
        client,
        email=address,
        password=password,
        account_type="buyer",
        display_name="Reset Tester",
    )
    return {"email": address, "password": password, "refresh": body["refresh_token"]}


def _generic_payload(response) -> dict:
    assert response.status_code == 200, response.text
    body = response.json()
    assert set(body.keys()) == {"message"}
    assert body["message"] == GENERIC_PASSWORD_RESET_MESSAGE
    return body


@pytest.mark.asyncio
async def test_password_reset_request_existing_email(client: AsyncClient):
    user = await _register(client)
    response = await client.post("/auth/password-reset/request", json={"email": user["email"]})
    _generic_payload(response)


@pytest.mark.asyncio
async def test_password_reset_request_unknown_email(client: AsyncClient):
    response = await client.post(
        "/auth/password-reset/request",
        json={"email": "missing-user@example.com"},
    )
    _generic_payload(response)


@pytest.mark.asyncio
async def test_password_reset_request_responses_are_identical(client: AsyncClient):
    user = await _register(client)
    existing = await client.post("/auth/password-reset/request", json={"email": user["email"]})
    missing = await client.post(
        "/auth/password-reset/request",
        json={"email": "nobody@example.com"},
    )
    assert existing.status_code == missing.status_code == 200
    assert existing.json() == missing.json()


@pytest.mark.asyncio
async def test_forgot_password_alias_matches_primary_route(client: AsyncClient):
    user = await _register(client)
    primary = await client.post("/auth/password-reset/request", json={"email": user["email"]})
    alias = await client.post("/auth/forgot-password", json={"email": user["email"]})
    assert primary.status_code == alias.status_code == 200
    assert primary.json() == alias.json()


@pytest.mark.asyncio
async def test_password_reset_token_is_hashed_in_database(client: AsyncClient):
    user = await _register(client)
    await client.post("/auth/password-reset/request", json={"email": user["email"]})

    async with database.SessionLocal() as session:
        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        token = (
            await session.execute(
                select(AuthToken).where(
                    AuthToken.user_id == db_user.id,
                    AuthToken.purpose == "password_reset",
                )
            )
        ).scalar_one()
        assert len(token.token_hash) == 64
        assert all(ch in "0123456789abcdef" for ch in token.token_hash)
        assert token.token_hash != user["email"]
        assert token.used_at is None


@pytest.mark.asyncio
async def test_password_reset_token_consumption_and_reuse(client: AsyncClient):
    user = await _register(client)
    await client.post("/auth/password-reset/request", json={"email": user["email"]})

    async with database.SessionLocal() as session:
        from app.routers.auth import _issue_auth_token

        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        plain = await _issue_auth_token(session, db_user.id, "password_reset", hours=2)
        await session.commit()

    first = await client.post(
        "/auth/reset-password",
        json={"token": plain, "new_password": "NewSecure1"},
    )
    assert first.status_code == 204, first.text

    reused = await client.post(
        "/auth/reset-password",
        json={"token": plain, "new_password": "AnotherSecure1"},
    )
    assert reused.status_code == 400


@pytest.mark.asyncio
async def test_password_reset_expired_token_rejected(client: AsyncClient):
    user = await _register(client)

    async with database.SessionLocal() as session:
        from app.routers.auth import _issue_auth_token

        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        plain = await _issue_auth_token(session, db_user.id, "password_reset", hours=2)
        token = (
            await session.execute(
                select(AuthToken).where(AuthToken.token_hash == _hash_token(plain))
            )
        ).scalar_one()
        token.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        await session.commit()

    response = await client.post(
        "/auth/password-reset/confirm",
        json={"token": plain, "new_password": "NewSecure1"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid or expired reset token"


@pytest.mark.asyncio
async def test_password_reset_updates_password_and_invalidates_sessions(client: AsyncClient):
    user = await _register(client)
    refresh = user["refresh"]

    async with database.SessionLocal() as session:
        from app.routers.auth import _issue_auth_token

        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        plain = await _issue_auth_token(session, db_user.id, "password_reset", hours=2)
        await session.commit()

    confirm = await client.post(
        "/auth/password-reset/confirm",
        json={"token": plain, "new_password": "NewSecure1"},
    )
    assert confirm.status_code == 204, confirm.text

    old_login = await client.post(
        "/auth/login",
        json={"email": user["email"], "password": user["password"]},
    )
    assert old_login.status_code == 401

    new_login = await client.post(
        "/auth/login",
        json={"email": user["email"], "password": "NewSecure1"},
    )
    assert new_login.status_code == 200, new_login.text

    refresh_attempt = await client.post(
        "/auth/refresh",
        json={"refresh_token": refresh},
    )
    assert refresh_attempt.status_code == 401


@pytest.mark.asyncio
async def test_password_reset_request_invalidates_previous_active_tokens(client: AsyncClient):
    user = await _register(client)
    await client.post("/auth/password-reset/request", json={"email": user["email"]})

    async with database.SessionLocal() as session:
        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        first_token = (
            await session.execute(
                select(AuthToken).where(
                    AuthToken.user_id == db_user.id,
                    AuthToken.purpose == "password_reset",
                )
            )
        ).scalar_one()
        first_hash = first_token.token_hash
        first_used = first_token.used_at

    await client.post("/auth/password-reset/request", json={"email": user["email"]})

    async with database.SessionLocal() as session:
        invalidated = (
            await session.execute(select(AuthToken).where(AuthToken.token_hash == first_hash))
        ).scalar_one()
        assert invalidated.used_at is not None
        assert invalidated.used_at != first_used


@pytest.mark.asyncio
async def test_password_reset_skips_deleted_accounts(client: AsyncClient):
    user = await _register(client)

    async with database.SessionLocal() as session:
        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        db_user.status = UserStatus.DELETED
        await session.commit()

    response = await client.post("/auth/password-reset/request", json={"email": user["email"]})
    _generic_payload(response)

    async with database.SessionLocal() as session:
        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        tokens = (
            await session.execute(
                select(AuthToken).where(
                    AuthToken.user_id == db_user.id,
                    AuthToken.purpose == "password_reset",
                )
            )
        ).scalars().all()
        assert tokens == []


@pytest.mark.asyncio
async def test_password_reset_confirm_invalid_input(client: AsyncClient):
    short_token = await client.post(
        "/auth/reset-password",
        json={"token": "short", "new_password": "NewSecure1"},
    )
    assert short_token.status_code == 422

    weak_password = await client.post(
        "/auth/reset-password",
        json={"token": "a" * 32, "new_password": "weak"},
    )
    assert weak_password.status_code in {400, 422}


@pytest.mark.asyncio
async def test_password_reset_request_rate_limited(client: AsyncClient):
    from app.limiter import limiter

    route_limit = limiter._route_limits["app.routers.auth.request_password_reset"][0]
    original = route_limit.limit
    route_limit.limit = parse("2/minute")
    limiter.reset()

    try:
        for _ in range(2):
            response = await client.post(
                "/auth/forgot-password",
                json={"email": "rate-limit@example.com"},
            )
            assert response.status_code == 200

        limited = await client.post(
            "/auth/forgot-password",
            json={"email": "rate-limit@example.com"},
        )
        assert limited.status_code == 429
    finally:
        route_limit.limit = original
        limiter.reset()


@pytest.mark.asyncio
async def test_password_reset_confirm_rate_limited(client: AsyncClient):
    from app.limiter import limiter

    route_limit = limiter._route_limits["app.routers.auth.confirm_password_reset"][0]
    original = route_limit.limit
    route_limit.limit = parse("2/minute")
    limiter.reset()

    payload = {"token": "x" * 32, "new_password": "NewSecure1"}
    try:
        for _ in range(2):
            response = await client.post("/auth/reset-password", json=payload)
            assert response.status_code == 400

        limited = await client.post("/auth/reset-password", json=payload)
        assert limited.status_code == 429
    finally:
        route_limit.limit = original
        limiter.reset()


@pytest.mark.asyncio
async def test_password_reset_failed_attempts_lock_expired_token(client: AsyncClient):
    user = await _register(client)

    async with database.SessionLocal() as session:
        from app.routers.auth import _issue_auth_token

        db_user = (
            await session.execute(select(User).where(User.email == user["email"]))
        ).scalar_one()
        plain = await _issue_auth_token(session, db_user.id, "password_reset", hours=2)
        token = (
            await session.execute(select(AuthToken).where(AuthToken.token_hash == _hash_token(plain)))
        ).scalar_one()
        token.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        await session.commit()

    for _ in range(5):
        bad = await client.post(
            "/auth/reset-password",
            json={"token": plain, "new_password": "NewSecure1"},
        )
        assert bad.status_code == 400

    locked = await client.post(
        "/auth/reset-password",
        json={"token": plain, "new_password": "NewSecure1"},
    )
    assert locked.status_code == 400

    async with database.SessionLocal() as session:
        token = (
            await session.execute(select(AuthToken).where(AuthToken.token_hash == _hash_token(plain)))
        ).scalar_one()
        assert token.used_at is not None
