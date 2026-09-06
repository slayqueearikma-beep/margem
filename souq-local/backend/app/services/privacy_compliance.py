"""Privacy rights workflow and consent evidence (Law 09-08 Art. 4, 7, 8, 9)."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    PrivacyRequest,
    PrivacyRequestStatus,
    PrivacyRequestType,
    UserConsent,
)
from app.services.legal_acceptance import _load_manifest

CONSENT_DEFINITIONS: dict[str, dict[str, str]] = {
    "marketing_email": {
        "purpose": "Direct marketing communications by email or in-app message",
        "legal_basis": "consent",
        "article": "Law 09-08 Art. 4, 9, 10",
    },
    "personalized_recommendations": {
        "purpose": "Optional marketplace recommendation personalization",
        "legal_basis": "consent",
        "article": "Law 09-08 Art. 4 (optional feature)",
    },
}


def _privacy_policy_version() -> str:
    manifest = _load_manifest()
    for doc in manifest.get("documents", []):
        if doc.get("id") == "privacy_policy":
            return str(doc.get("version", ""))
    return ""


async def get_latest_consents(session: AsyncSession, user_id: UUID) -> dict[str, bool]:
    """Return the latest granted state per consent_type for a user."""
    rows = (
        await session.execute(
            select(UserConsent)
            .where(UserConsent.user_id == user_id)
            .order_by(UserConsent.consent_type, desc(UserConsent.recorded_at))
        )
    ).scalars().all()
    latest: dict[str, bool] = {}
    for row in rows:
        if row.consent_type not in latest:
            latest[row.consent_type] = row.granted
    return latest


async def record_user_consent(
    session: AsyncSession,
    *,
    user_id: UUID,
    consent_type: str,
    granted: bool,
    language: str,
    source: str,
    ip_address: str,
    user_agent: str,
) -> UserConsent:
    if consent_type not in CONSENT_DEFINITIONS:
        raise ValueError(f"Unknown consent type: {consent_type}")

    definition = CONSENT_DEFINITIONS[consent_type]
    now = datetime.now(UTC)
    row = UserConsent(
        user_id=user_id,
        consent_type=consent_type,
        purpose=definition["purpose"],
        granted=granted,
        policy_version=_privacy_policy_version(),
        language=language[:8] if language else "en",
        source=source[:64],
        recorded_at=now,
        withdrawn_at=None if granted else now,
        ip_address=ip_address[:64],
        user_agent=user_agent[:512],
    )
    session.add(row)
    await session.flush()
    return row


async def list_consent_history(
    session: AsyncSession, user_id: UUID, *, limit: int = 50
) -> list[UserConsent]:
    result = await session.execute(
        select(UserConsent)
        .where(UserConsent.user_id == user_id)
        .order_by(desc(UserConsent.recorded_at))
        .limit(limit)
    )
    return list(result.scalars().all())


async def create_privacy_request(
    session: AsyncSession,
    *,
    user_id: UUID,
    request_type: PrivacyRequestType,
    details: str,
    ip_address: str,
    user_agent: str,
) -> PrivacyRequest:
    if request_type == PrivacyRequestType.ERASURE:
        existing = (
            await session.execute(
                select(PrivacyRequest).where(
                    PrivacyRequest.user_id == user_id,
                    PrivacyRequest.request_type == PrivacyRequestType.ERASURE,
                    PrivacyRequest.status.in_(
                        [PrivacyRequestStatus.PENDING, PrivacyRequestStatus.IN_REVIEW]
                    ),
                )
            )
        ).scalar_one_or_none()
        if existing is not None:
            return existing

    now = datetime.now(UTC)
    request = PrivacyRequest(
        user_id=user_id,
        request_type=request_type,
        status=PrivacyRequestStatus.PENDING,
        details=details[:4000],
        ip_address=ip_address[:64],
        user_agent=user_agent[:512],
        verified_at=now,
        audit_metadata={"identity_verified_via": "authenticated_session"},
    )

    if request_type == PrivacyRequestType.ACCESS:
        request.status = PrivacyRequestStatus.COMPLETED
        request.completed_at = now
        request.resolution_notes = (
            "Self-service access fulfilled via GET /auth/me/export in the mobile app "
            "or authenticated API export endpoint."
        )
    elif request_type == PrivacyRequestType.OPPOSITION and _is_marketing_opposition(details):
        await record_user_consent(
            session,
            user_id=user_id,
            consent_type="marketing_email",
            granted=False,
            language="en",
            source="privacy_request_opposition",
            ip_address=ip_address,
            user_agent=user_agent,
        )
        request.status = PrivacyRequestStatus.COMPLETED
        request.completed_at = now
        request.resolution_notes = "Marketing opposition recorded; direct marketing consent withdrawn."

    session.add(request)
    await session.flush()
    return request


def _is_marketing_opposition(details: str) -> bool:
    lowered = details.lower()
    return any(token in lowered for token in ("marketing", "prospection", "email promo", "newsletter"))


async def list_user_privacy_requests(
    session: AsyncSession, user_id: UUID, *, limit: int = 50
) -> list[PrivacyRequest]:
    result = await session.execute(
        select(PrivacyRequest)
        .where(PrivacyRequest.user_id == user_id)
        .order_by(desc(PrivacyRequest.created_at))
        .limit(limit)
    )
    return list(result.scalars().all())


async def get_user_privacy_request(
    session: AsyncSession, user_id: UUID, request_id: UUID
) -> PrivacyRequest | None:
    result = await session.execute(
        select(PrivacyRequest).where(
            PrivacyRequest.id == request_id,
            PrivacyRequest.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()
