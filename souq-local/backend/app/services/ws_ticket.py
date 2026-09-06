"""Short-lived WebSocket connection tickets (avoid JWT in query strings)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from fastapi import HTTPException, status

from app.config import settings

_AUDIENCE_COMMUNITY = "margem-ws-community"
_AUDIENCE_MARKETPLACE = "margem-ws-marketplace"
_TTL_SECONDS = 60


def issue_ws_ticket(*, user_id: UUID, channel_id: UUID, audience: str) -> str:
    secret = (settings.upload_token_secret or settings.jwt_secret_key).strip()
    if len(secret) < 32:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="WebSocket tickets are not configured",
        )
    now = datetime.now(UTC)
    payload = {
        "sub": str(user_id),
        "aud": audience,
        "ch": str(channel_id),
        "typ": "ws",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=_TTL_SECONDS)).timestamp()),
    }
    return jwt.encode(payload, secret, algorithm=settings.jwt_algorithm)


def verify_ws_ticket(ticket: str, *, channel_id: UUID, audience: str) -> UUID:
    secret = (settings.upload_token_secret or settings.jwt_secret_key).strip()
    try:
        payload = jwt.decode(
            ticket,
            secret,
            algorithms=[settings.jwt_algorithm],
            audience=audience,
            options={"require": ["exp", "sub", "aud", "ch", "typ"]},
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid WebSocket ticket") from exc
    if payload.get("typ") != "ws":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid WebSocket ticket")
    if payload.get("ch") != str(channel_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="WebSocket ticket channel mismatch")
    return UUID(str(payload["sub"]))


def community_audience() -> str:
    return _AUDIENCE_COMMUNITY


def marketplace_audience() -> str:
    return _AUDIENCE_MARKETPLACE
