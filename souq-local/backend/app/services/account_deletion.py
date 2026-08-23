"""Account deletion and erasure — shared orchestration for DELETE /auth/me and privacy erasure."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import delete as sql_delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AuthToken,
    Conversation,
    Favorite,
    Message,
    MfaFactor,
    MfaRecoveryCode,
    Notification,
    RecentlyViewed,
    Review,
    SavedSearch,
    SellerFollow,
    SellerProfile,
    Subscription,
    User,
    UserBlock,
    UserStatus,
)
from app.models.community import (
    CommunityMembership,
    CommunityMessage,
    CommunityMessageStatus,
    CommunityReaction,
    CommunityReport,
    CommunityUserBlock,
    CommunityUserMute,
)
from app.models.marketplace_community import (
    MarketplaceCommunityBan,
    MarketplaceCommunityMembership,
    MarketplaceCommunityMessage,
    MarketplaceMessageStatus,
    MarketplaceCommunityReaction,
    MarketplaceCommunityReport,
)
from app.services.audit import log_security_event
from app.services.media_lifecycle import delete_all_user_media, log_media_event
from app.services.media_registry import mark_user_media_deleted
from app.services.security import revoke_all_refresh_tokens


async def delete_user_account(session: AsyncSession, user: User) -> None:
    """Anonymize/delete user-owned data. Caller must verify authentication/password."""
    seller = await session.execute(select(SellerProfile).where(SellerProfile.user_id == user.id))
    profile = seller.scalar_one_or_none()

    await session.execute(sql_delete(Message).where(Message.sender_id == user.id))
    peer_conversations = (
        await session.execute(
            select(Conversation.id).where(
                (Conversation.participant_a_id == user.id) | (Conversation.participant_b_id == user.id)
            )
        )
    ).scalars().all()
    if peer_conversations:
        await session.execute(sql_delete(Message).where(Message.conversation_id.in_(peer_conversations)))
        await session.execute(sql_delete(Conversation).where(Conversation.id.in_(peer_conversations)))

    user_messages = (
        await session.execute(select(CommunityMessage.id).where(CommunityMessage.sender_id == user.id))
    ).scalars().all()
    if user_messages:
        await session.execute(sql_delete(CommunityReaction).where(CommunityReaction.message_id.in_(user_messages)))
        await session.execute(sql_delete(CommunityReport).where(CommunityReport.message_id.in_(user_messages)))
    await session.execute(sql_delete(CommunityReport).where(CommunityReport.reporter_id == user.id))
    await session.execute(sql_delete(CommunityMembership).where(CommunityMembership.user_id == user.id))
    await session.execute(sql_delete(CommunityUserBlock).where(CommunityUserBlock.blocker_id == user.id))
    await session.execute(sql_delete(CommunityUserBlock).where(CommunityUserBlock.blocked_id == user.id))
    await session.execute(sql_delete(CommunityUserMute).where(CommunityUserMute.muter_id == user.id))
    await session.execute(sql_delete(CommunityUserMute).where(CommunityUserMute.muted_id == user.id))
    await session.execute(sql_delete(UserBlock).where(UserBlock.blocker_id == user.id))
    await session.execute(sql_delete(UserBlock).where(UserBlock.blocked_id == user.id))

    mp_user_messages = (
        await session.execute(
            select(MarketplaceCommunityMessage.id).where(MarketplaceCommunityMessage.sender_id == user.id)
        )
    ).scalars().all()
    if mp_user_messages:
        await session.execute(
            sql_delete(MarketplaceCommunityReaction).where(
                MarketplaceCommunityReaction.message_id.in_(mp_user_messages)
            )
        )
        await session.execute(
            sql_delete(MarketplaceCommunityReport).where(
                MarketplaceCommunityReport.message_id.in_(mp_user_messages)
            )
        )
    await session.execute(
        sql_delete(MarketplaceCommunityReport).where(MarketplaceCommunityReport.reporter_id == user.id)
    )
    await session.execute(
        sql_delete(MarketplaceCommunityMembership).where(MarketplaceCommunityMembership.user_id == user.id)
    )
    await session.execute(
        sql_delete(MarketplaceCommunityBan).where(MarketplaceCommunityBan.user_id == user.id)
    )
    await session.execute(
        update(MarketplaceCommunityMessage)
        .where(MarketplaceCommunityMessage.sender_id == user.id)
        .values(
            body="[deleted]",
            status=MarketplaceMessageStatus.DELETED,
            deleted_at=datetime.now(UTC),
            deleted_by_id=user.id,
        )
    )

    if profile is not None:
        from app.models import Product, SellerCategory, Service

        await session.execute(sql_delete(SellerCategory).where(SellerCategory.seller_id == profile.id))
        await session.execute(sql_delete(Product).where(Product.seller_id == profile.id))
        await session.execute(sql_delete(Service).where(Service.seller_id == profile.id))
        await session.execute(sql_delete(Review).where(Review.seller_id == profile.id))
        await session.delete(profile)

    for model, column in (
        (Favorite, Favorite.user_id),
        (SellerFollow, SellerFollow.user_id),
        (SavedSearch, SavedSearch.user_id),
        (RecentlyViewed, RecentlyViewed.user_id),
        (Notification, Notification.user_id),
        (Subscription, Subscription.user_id),
        (AuthToken, AuthToken.user_id),
        (Review, Review.buyer_id),
        (MfaFactor, MfaFactor.user_id),
        (MfaRecoveryCode, MfaRecoveryCode.user_id),
        (CommunityMembership, CommunityMembership.user_id),
        (CommunityReaction, CommunityReaction.user_id),
        (CommunityReport, CommunityReport.reporter_id),
        (MarketplaceCommunityMembership, MarketplaceCommunityMembership.user_id),
        (MarketplaceCommunityReaction, MarketplaceCommunityReaction.user_id),
        (MarketplaceCommunityReport, MarketplaceCommunityReport.reporter_id),
    ):
        await session.execute(sql_delete(model).where(column == user.id))

    await session.execute(
        update(CommunityMessage)
        .where(CommunityMessage.sender_id == user.id)
        .values(
            body="[deleted]",
            attachments=[],
            mentions=[],
            hashtags=[],
            status=CommunityMessageStatus.DELETED,
            deleted_at=datetime.now(UTC),
            deleted_by_id=user.id,
        )
    )

    await revoke_all_refresh_tokens(session, user.id)
    user.status = UserStatus.DELETED
    user.email = f"deleted+{user.id}@invalid.local"
    user.display_name = "Deleted user"
    user.phone = ""
    user.profile_photo_url = ""
    user.password_hash = None
    user.firebase_uid = f"deleted-{user.id}"
    user.email_verified_at = None
    user.mfa_enabled = False
    user.is_premium = False
    user.premium_until = None

    await mark_user_media_deleted(session, user.id)

    purged = await delete_all_user_media(user.id)
    log_media_event("profile_photo_deleted", user_id=user.id, purpose="account_deletion", detail=f"count={purged}")
    log_security_event("account_deleted", user_id=str(user.id))
