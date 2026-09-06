"""Electronic agreement evidence helpers (Morocco Law 53-05 / DOC Art. 417-1–417-3)."""

from __future__ import annotations

from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import SubscriptionAgreementRecord, SubscriptionPlan, User
from app.services.legal_acceptance import (
    _documents_by_id,
    document_hash_for_policy,
    normalize_acceptance_language,
    record_policy_acceptances,
)

SELLER_AGREEMENT_POLICY_ID = "seller_terms"
SUBSCRIPTION_AGREEMENT_POLICY_ID = "subscription_terms"


async def record_seller_agreement_acceptance(
    session: AsyncSession,
    *,
    user_id: UUID,
    language: str,
    ip_address: str,
    user_agent: str,
    session_reference: str = "",
) -> None:
    await record_policy_acceptances(
        session,
        user_id=user_id,
        policy_ids=[SELLER_AGREEMENT_POLICY_ID],
        language=language,
        ip_address=ip_address,
        user_agent=user_agent,
        source="seller_onboarding",
        authentication_method="bearer_session",
        session_reference=session_reference,
        allow_contextual=True,
    )


async def record_subscription_agreement_acceptance(
    session: AsyncSession,
    *,
    user: User,
    plan: SubscriptionPlan,
    language: str,
    ip_address: str,
    user_agent: str,
    provider_reference: str = "",
    subscription_id: UUID | None = None,
) -> SubscriptionAgreementRecord:
    docs = _documents_by_id()
    doc = docs.get(SUBSCRIPTION_AGREEMENT_POLICY_ID)
    if doc is None:
        raise ValueError("subscription_terms document not published")

    version = str(doc.get("version", ""))
    doc_hash = document_hash_for_policy(SUBSCRIPTION_AGREEMENT_POLICY_ID, language=language)
    normalized_lang = normalize_acceptance_language(language)

    await record_policy_acceptances(
        session,
        user_id=user.id,
        policy_ids=[SUBSCRIPTION_AGREEMENT_POLICY_ID],
        language=normalized_lang,
        ip_address=ip_address,
        user_agent=user_agent,
        source="subscription_checkout",
        authentication_method="bearer_session",
        allow_contextual=True,
    )

    row = SubscriptionAgreementRecord(
        user_id=user.id,
        subscription_id=subscription_id,
        plan_code=plan.code,
        plan_price_mad=float(plan.price_mad),
        billing_period_days=plan.billing_period_days,
        policy_id=SUBSCRIPTION_AGREEMENT_POLICY_ID,
        policy_version=version,
        document_hash=doc_hash,
        language=normalized_lang,
        ip_address=ip_address[:64],
        user_agent=user_agent[:512],
        provider_reference=provider_reference[:120],
    )
    session.add(row)
    await session.flush()
    return row


async def link_subscription_agreement_to_checkout(
    session: AsyncSession,
    *,
    user_id: UUID,
    subscription_id: UUID,
    provider_reference: str,
) -> None:
    """Attach fulfilled subscription to the pending checkout agreement record."""
    if not provider_reference:
        return
    pending_ref = "naps_checkout_pending"
    row = (
        await session.execute(
            select(SubscriptionAgreementRecord)
            .where(
                SubscriptionAgreementRecord.user_id == user_id,
                SubscriptionAgreementRecord.provider_reference == pending_ref,
                SubscriptionAgreementRecord.subscription_id.is_(None),
            )
            .order_by(SubscriptionAgreementRecord.accepted_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if row is None:
        return
    row.subscription_id = subscription_id
    row.provider_reference = provider_reference[:120]
    await session.flush()
