"""Legal policy acceptance — manifest-driven versioning and user records."""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import LegalAcceptance

_MANIFEST_PATH = (
    Path(__file__).resolve().parents[2] / "static" / "legal" / "manifest.json"
)
_STATIC_LEGAL_ROOT = _MANIFEST_PATH.parent

# Policies that must be accepted before using the authenticated application.
ONBOARDING_POLICY_IDS: tuple[str, ...] = ("terms_of_service", "privacy_policy")

# Additional agreements recorded at contextual flows (seller onboarding, checkout).
CONTEXTUAL_POLICY_IDS: tuple[str, ...] = ("seller_terms", "subscription_terms")

_ACCEPTANCE_LANGUAGES = {"en", "fr", "ar"}


@dataclass(frozen=True)
class RequiredPolicy:
    policy_id: str
    policy_version: str
    slug: str


def _load_manifest() -> dict:
    if not _MANIFEST_PATH.is_file():
        return {"documents": []}
    return json.loads(_MANIFEST_PATH.read_text(encoding="utf-8"))


def _documents_by_id() -> dict[str, dict]:
    manifest = _load_manifest()
    return {
        doc["id"]: doc
        for doc in manifest.get("documents", [])
        if doc.get("id") and doc.get("status", "published") == "published"
    }


def get_required_onboarding_policies() -> list[RequiredPolicy]:
    docs = _documents_by_id()
    required: list[RequiredPolicy] = []
    for policy_id in ONBOARDING_POLICY_IDS:
        doc = docs.get(policy_id)
        if doc is None:
            continue
        required.append(
            RequiredPolicy(
                policy_id=policy_id,
                policy_version=str(doc.get("version", "")),
                slug=str(doc.get("slug", "")),
            )
        )
    return required


def normalize_acceptance_language(language: str) -> str:
    code = (language or "en").strip().lower().split("-")[0]
    if code not in _ACCEPTANCE_LANGUAGES:
        return "en"
    return code


def document_hash_for_policy(policy_id: str, *, language: str = "en") -> str:
    """SHA-256 of the published HTML document (integrity evidence under DOC Art. 417-1)."""
    docs = _documents_by_id()
    doc = docs.get(policy_id)
    if doc is None:
        return ""
    slug = str(doc.get("slug", ""))
    lang = normalize_acceptance_language(language)
    for candidate in (lang, "en", "fr"):
        path = _STATIC_LEGAL_ROOT / candidate / f"{slug}.html"
        if path.is_file():
            return hashlib.sha256(path.read_bytes()).hexdigest()
    return ""


async def get_user_acceptances(
    session: AsyncSession, user_id: UUID
) -> dict[str, str]:
    """Map policy_id -> latest accepted version for the user."""
    result = await session.execute(
        select(LegalAcceptance).where(LegalAcceptance.user_id == user_id)
    )
    latest: dict[str, str] = {}
    for row in result.scalars().all():
        current = latest.get(row.policy_id)
        if current is None or row.policy_version > current:
            latest[row.policy_id] = row.policy_version
    return latest


async def get_pending_policy_ids(session: AsyncSession, user_id: UUID) -> list[str]:
    accepted = await get_user_acceptances(session, user_id)
    pending: list[str] = []
    for policy in get_required_onboarding_policies():
        if accepted.get(policy.policy_id) != policy.policy_version:
            pending.append(policy.policy_id)
    return pending


async def is_legal_acceptance_complete(session: AsyncSession, user_id: UUID) -> bool:
    return not await get_pending_policy_ids(session, user_id)


async def record_policy_acceptances(
    session: AsyncSession,
    *,
    user_id: UUID,
    policy_ids: list[str],
    language: str,
    ip_address: str = "",
    user_agent: str = "",
    source: str = "legal_accept",
    authentication_method: str = "bearer_session",
    session_reference: str = "",
    allow_contextual: bool = False,
) -> list[str]:
    """Record acceptances for the current manifest versions. Returns accepted policy ids."""
    docs = _documents_by_id()
    required = {p.policy_id: p for p in get_required_onboarding_policies()}
    allowed = set(required.keys())
    if allow_contextual:
        allowed |= set(CONTEXTUAL_POLICY_IDS)
    normalized_lang = normalize_acceptance_language(language)
    now = datetime.now(UTC)
    accepted_ids: list[str] = []

    for policy_id in policy_ids:
        if policy_id not in allowed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unknown or non-required policy: {policy_id}",
            )
        doc = docs.get(policy_id)
        if doc is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Policy not found: {policy_id}",
            )
        version = str(doc.get("version", ""))
        if not version:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Policy version missing for {policy_id}",
            )
        doc_hash = document_hash_for_policy(policy_id, language=normalized_lang)

        stmt = (
            insert(LegalAcceptance)
            .values(
                user_id=user_id,
                policy_id=policy_id,
                policy_version=version,
                language=normalized_lang,
                accepted_at=now,
                ip_address=ip_address[:64],
                user_agent=user_agent[:512],
                document_hash=doc_hash,
                authentication_method=authentication_method[:32],
                source=source[:64],
                session_reference=session_reference[:128],
            )
            .on_conflict_do_nothing(
                index_elements=["user_id", "policy_id", "policy_version"]
            )
        )
        await session.execute(stmt)
        accepted_ids.append(policy_id)

    return accepted_ids


def build_acceptance_status(
    *,
    accepted_versions: dict[str, str],
    pending_ids: list[str],
) -> dict:
    required = get_required_onboarding_policies()
    accepted_records = [
        {
            "policy_id": policy.policy_id,
            "policy_version": accepted_versions[policy.policy_id],
            "slug": policy.slug,
            "document_hash": document_hash_for_policy(
                policy.policy_id, language="en"
            ),
        }
        for policy in required
        if policy.policy_id in accepted_versions
        and accepted_versions[policy.policy_id] == policy.policy_version
    ]
    return {
        "required": [
            {
                "policy_id": p.policy_id,
                "policy_version": p.policy_version,
                "slug": p.slug,
            }
            for p in required
        ],
        "pending": pending_ids,
        "accepted": accepted_records,
        "complete": not pending_ids,
    }
