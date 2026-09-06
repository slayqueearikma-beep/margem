"""Assemble a machine-readable personal-data export for Law 09-08 Art. 7."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Favorite,
    LegalAcceptance,
    Message,
    Notification,
    PrivacyRequest,
    Review,
    SellerProfile,
    Subscription,
    SubscriptionAgreementRecord,
    User,
    UserConsent,
)


async def build_user_data_export(session: AsyncSession, user: User) -> dict:
    seller = (
        await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    ).scalar_one_or_none()
    favorites = (
        await session.execute(select(Favorite).where(Favorite.user_id == user.id).limit(500))
    ).scalars().all()
    notifications = (
        await session.execute(select(Notification).where(Notification.user_id == user.id).limit(200))
    ).scalars().all()
    subscriptions = (
        await session.execute(select(Subscription).where(Subscription.user_id == user.id))
    ).scalars().all()
    reviews = (
        await session.execute(select(Review).where(Review.buyer_id == user.id).limit(200))
    ).scalars().all()
    messages = (
        await session.execute(select(Message).where(Message.sender_id == user.id).limit(200))
    ).scalars().all()
    legal_acceptances = (
        await session.execute(select(LegalAcceptance).where(LegalAcceptance.user_id == user.id))
    ).scalars().all()
    subscription_agreements = (
        await session.execute(
            select(SubscriptionAgreementRecord).where(SubscriptionAgreementRecord.user_id == user.id)
        )
    ).scalars().all()
    consents = (
        await session.execute(
            select(UserConsent).where(UserConsent.user_id == user.id).order_by(UserConsent.recorded_at.desc()).limit(50)
        )
    ).scalars().all()
    privacy_requests = (
        await session.execute(
            select(PrivacyRequest)
            .where(PrivacyRequest.user_id == user.id)
            .order_by(PrivacyRequest.created_at.desc())
            .limit(50)
        )
    ).scalars().all()

    return {
        "exported_at": datetime.now(UTC).isoformat(),
        "export_format": "dribex-json-v1",
        "user": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "phone": user.phone,
            "profile_photo_url": getattr(user, "profile_photo_url", "") or "",
            "account_type": user.account_type.value,
            "role": user.role.value,
            "status": user.status.value,
            "email_verified": user.email_verified_at is not None,
            "created_at": user.created_at.isoformat(),
            "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
        },
        "seller_profile": (
            {
                "business_name": seller.business_name,
                "city": seller.city,
                "address": seller.address,
                "phone": seller.phone,
                "verification_status": seller.verification_status.value,
                "logo_image_url": seller.logo_image_url,
                "cover_image_url": seller.cover_image_url,
            }
            if seller
            else None
        ),
        "favorites": [
            {
                "seller_id": str(fav.seller_id) if fav.seller_id else None,
                "product_id": str(fav.product_id) if fav.product_id else None,
                "created_at": fav.created_at.isoformat(),
            }
            for fav in favorites
        ],
        "reviews_written": [
            {
                "id": str(review.id),
                "seller_id": str(review.seller_id),
                "rating": review.rating,
                "comment": review.comment,
                "created_at": review.created_at.isoformat(),
            }
            for review in reviews
        ],
        "messages_sent": [
            {
                "id": str(msg.id),
                "conversation_id": str(msg.conversation_id),
                "body": msg.body,
                "created_at": msg.created_at.isoformat(),
            }
            for msg in messages
        ],
        "notifications": [
            {
                "id": str(note.id),
                "kind": note.kind,
                "title": note.title,
                "body": note.body,
                "read_at": note.read_at.isoformat() if note.read_at else None,
                "created_at": note.created_at.isoformat(),
            }
            for note in notifications
        ],
        "subscriptions": [
            {
                "status": sub.status.value,
                "plan_id": str(sub.plan_id),
                "current_period_end": sub.current_period_end.isoformat(),
            }
            for sub in subscriptions
        ],
        "legal_acceptances": [
            {
                "policy_id": row.policy_id,
                "policy_version": row.policy_version,
                "language": row.language,
                "accepted_at": row.accepted_at.isoformat(),
                "document_hash": row.document_hash,
                "source": row.source,
                "authentication_method": row.authentication_method,
            }
            for row in legal_acceptances
        ],
        "subscription_agreements": [
            {
                "plan_code": row.plan_code,
                "plan_price_mad": float(row.plan_price_mad),
                "billing_period_days": row.billing_period_days,
                "policy_id": row.policy_id,
                "policy_version": row.policy_version,
                "document_hash": row.document_hash,
                "accepted_at": row.accepted_at.isoformat(),
                "provider_reference": row.provider_reference,
            }
            for row in subscription_agreements
        ],
        "consents": [
            {
                "consent_type": row.consent_type,
                "granted": row.granted,
                "purpose": row.purpose,
                "policy_version": row.policy_version,
                "recorded_at": row.recorded_at.isoformat(),
                "withdrawn_at": row.withdrawn_at.isoformat() if row.withdrawn_at else None,
            }
            for row in consents
        ],
        "privacy_requests": [
            {
                "id": str(row.id),
                "request_type": row.request_type.value,
                "status": row.status.value,
                "created_at": row.created_at.isoformat(),
                "completed_at": row.completed_at.isoformat() if row.completed_at else None,
            }
            for row in privacy_requests
        ],
        "retention_notice": (
            "Some categories may be retained after account deletion where required by law "
            "(billing, fraud prevention, legal holds). See account-deletion policy."
        ),
    }
