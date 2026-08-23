import asyncio
import logging
import re
from uuid import UUID, uuid4

logger = logging.getLogger("margem.security")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def _mask_value(key: str, value: object) -> object:
    if key.lower() in {"email", "to", "recipient"} and isinstance(value, str) and "@" in value:
        local, _, domain = value.partition("@")
        if not local:
            return f"[redacted]@{domain}"
        return f"{local[0]}***@{domain}"
    if key.lower() in {"token", "access_token", "refresh_token", "password"}:
        return "[redacted]"
    if isinstance(value, str) and _EMAIL_RE.match(value):
        local, _, domain = value.partition("@")
        return f"{local[0]}***@{domain}"
    return value


async def _persist_security_event(event: str, safe: dict[str, object]) -> None:
    from app.database import SessionLocal
    from app.models import SecurityEvent

    user_id_raw = safe.get("user_id")
    user_id: UUID | None = None
    if user_id_raw:
        try:
            user_id = UUID(str(user_id_raw))
        except ValueError:
            user_id = None

    ip_address = str(safe.get("client") or safe.get("ip_address") or "")[:64]
    metadata = {k: v for k, v in safe.items() if k not in {"user_id", "client", "ip_address"}}

    async with SessionLocal() as session:
        session.add(
            SecurityEvent(
                id=uuid4(),
                event_type=event[:80],
                user_id=user_id,
                ip_address=ip_address,
                metadata_=metadata,
            )
        )
        await session.commit()


def log_security_event(event: str, **details: object) -> None:
    safe = {k: _mask_value(k, v) for k, v in details.items()}
    logger.warning(
        "security_event=%s %s",
        event,
        " ".join(f"{k}={v}" for k, v in safe.items()),
    )
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(_persist_security_event(event, safe))
    except RuntimeError:
        # No event loop (e.g. sync test context) — logger-only fallback.
        pass
