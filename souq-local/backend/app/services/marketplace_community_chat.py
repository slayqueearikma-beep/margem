"""Marketplace community chat business logic."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import User
from app.models.marketplace import Marketplace
from app.models.marketplace_community import (
    MARKETPLACE_CHANNEL_SEEDS,
    MarketplaceCommunityBan,
    MarketplaceCommunityChannel,
    MarketplaceCommunityMembership,
    MarketplaceCommunityMessage,
    MarketplaceCommunityModerationLog,
    MarketplaceCommunityReport,
    MarketplaceMessageStatus,
    MarketplacePostType,
    MarketplaceReportStatus,
)
from app.schemas.marketplace_community import (
    MarketplaceCommunityMessageCreate,
    MarketplaceCommunityMessageOut,
    MarketplaceCommunitySenderOut,
)
from app.services.community_moderation import compute_spam_score, detect_language
from app.services.community_trust import sender_profile
from app.services.marketplace_community_spam import (
    check_message_allowed,
    raise_spam_rejection,
    record_successful_message,
)


async def ensure_marketplace_channels(session: AsyncSession, marketplace: Marketplace) -> None:
    existing = await session.scalar(
        select(func.count())
        .select_from(MarketplaceCommunityChannel)
        .where(MarketplaceCommunityChannel.marketplace_id == marketplace.id)
    )
    if int(existing or 0) > 0:
        return

    specs = MARKETPLACE_CHANNEL_SEEDS.get(marketplace.slug, [])
    if not specs:
        specs = [
            ("general", "General", f"Discussion for {marketplace.name}", MarketplacePostType.GENERAL),
        ]
    for order, (slug, name, description, post_type) in enumerate(specs):
        session.add(
            MarketplaceCommunityChannel(
                id=uuid4(),
                marketplace_id=marketplace.id,
                slug=slug,
                name=name,
                description=description,
                default_post_type=post_type,
                display_order=order,
            )
        )


async def get_marketplace_by_slug(session: AsyncSession, slug: str) -> Marketplace:
    marketplace = await session.scalar(
        select(Marketplace).where(Marketplace.slug == slug, Marketplace.is_active.is_(True))
    )
    if marketplace is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Marketplace not found")
    await ensure_marketplace_channels(session, marketplace)
    await session.flush()
    return marketplace


async def ensure_membership(session: AsyncSession, *, marketplace_id: UUID, user_id: UUID) -> None:
    membership = await session.scalar(
        select(MarketplaceCommunityMembership).where(
            MarketplaceCommunityMembership.marketplace_id == marketplace_id,
            MarketplaceCommunityMembership.user_id == user_id,
        )
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Join this marketplace community before participating",
        )


async def ensure_not_banned(session: AsyncSession, *, marketplace_id: UUID, user_id: UUID) -> None:
    ban = await session.scalar(
        select(MarketplaceCommunityBan).where(
            MarketplaceCommunityBan.marketplace_id == marketplace_id,
            MarketplaceCommunityBan.user_id == user_id,
        )
    )
    if ban is None:
        return
    if ban.expires_at and ban.expires_at < datetime.now(UTC):
        await session.delete(ban)
        return
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Banned from this marketplace community")


async def join_marketplace_community(
    session: AsyncSession, *, user: User, marketplace: Marketplace
) -> MarketplaceCommunityMembership:
    await ensure_not_banned(session, marketplace_id=marketplace.id, user_id=user.id)
    membership = await session.scalar(
        select(MarketplaceCommunityMembership).where(
            MarketplaceCommunityMembership.user_id == user.id,
            MarketplaceCommunityMembership.marketplace_id == marketplace.id,
        )
    )
    if membership is not None:
        return membership
    membership = MarketplaceCommunityMembership(
        id=uuid4(),
        user_id=user.id,
        marketplace_id=marketplace.id,
    )
    session.add(membership)
    return membership


async def get_channel(session: AsyncSession, channel_id: UUID) -> MarketplaceCommunityChannel:
    channel = await session.scalar(
        select(MarketplaceCommunityChannel)
        .options(selectinload(MarketplaceCommunityChannel.messages))
        .where(MarketplaceCommunityChannel.id == channel_id, MarketplaceCommunityChannel.is_active.is_(True))
    )
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")
    return channel


async def message_to_out(session: AsyncSession, message: MarketplaceCommunityMessage) -> MarketplaceCommunityMessageOut:
    sender = await session.get(User, message.sender_id)
    if sender is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sender not found")
    profile = await sender_profile(session, sender)
    return MarketplaceCommunityMessageOut(
        id=message.id,
        channel_id=message.channel_id,
        sender=MarketplaceCommunitySenderOut(
            id=sender.id,
            display_name=profile.display_name,
            is_verified=profile.is_verified,
            trust_score=profile.trust_score,
        ),
        body=message.body if message.status != MarketplaceMessageStatus.DELETED else "",
        post_type=message.post_type,
        reply_to_id=message.reply_to_id,
        status=message.status.value,
        is_pinned=message.is_pinned,
        is_edited=message.edited_at is not None,
        created_at=message.created_at,
        edited_at=message.edited_at,
    )


async def list_messages(
    session: AsyncSession,
    *,
    channel: MarketplaceCommunityChannel,
    viewer: User,
    limit: int = 50,
    before_id: UUID | None = None,
) -> list[MarketplaceCommunityMessageOut]:
    marketplace_id = channel.marketplace_id
    await ensure_not_banned(session, marketplace_id=marketplace_id, user_id=viewer.id)
    await ensure_membership(session, marketplace_id=marketplace_id, user_id=viewer.id)

    stmt = (
        select(MarketplaceCommunityMessage)
        .where(
            MarketplaceCommunityMessage.channel_id == channel.id,
            MarketplaceCommunityMessage.status.in_(
                [MarketplaceMessageStatus.VISIBLE, MarketplaceMessageStatus.PENDING_MODERATION]
            ),
        )
        .order_by(MarketplaceCommunityMessage.created_at.desc())
        .limit(limit)
    )
    if before_id is not None:
        pivot = await session.get(MarketplaceCommunityMessage, before_id)
        if pivot is not None:
            stmt = stmt.where(MarketplaceCommunityMessage.created_at < pivot.created_at)

    messages = list((await session.execute(stmt)).scalars().all())
    return [await message_to_out(session, message) for message in messages]


async def send_message(
    session: AsyncSession,
    *,
    channel: MarketplaceCommunityChannel,
    sender: User,
    payload: MarketplaceCommunityMessageCreate,
) -> MarketplaceCommunityMessage:
    marketplace_id = channel.marketplace_id
    await ensure_not_banned(session, marketplace_id=marketplace_id, user_id=sender.id)
    await ensure_membership(session, marketplace_id=marketplace_id, user_id=sender.id)

    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty")

    spam_check = await check_message_allowed(
        session,
        user_id=sender.id,
        marketplace_id=marketplace_id,
        channel_id=channel.id,
        body=body,
    )
    if not spam_check.allowed:
        raise_spam_rejection(spam_check)

    spam_score, spam_reason = compute_spam_score(body, recent_duplicate=False)
    status_value = MarketplaceMessageStatus.VISIBLE
    moderation_reason = ""
    if spam_score >= 0.75 or payload.post_type == MarketplacePostType.SCAM_REPORT:
        if spam_score >= 0.75:
            status_value = MarketplaceMessageStatus.PENDING_MODERATION
            moderation_reason = spam_reason or "spam"

    if payload.reply_to_id:
        reply = await session.get(MarketplaceCommunityMessage, payload.reply_to_id)
        if reply is None or reply.channel_id != channel.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply target not found")

    message = MarketplaceCommunityMessage(
        id=uuid4(),
        channel_id=channel.id,
        sender_id=sender.id,
        body=body,
        post_type=payload.post_type,
        reply_to_id=payload.reply_to_id,
        status=status_value,
        moderation_reason=moderation_reason,
        spam_score=spam_score,
    )
    session.add(message)
    channel.message_count = (channel.message_count or 0) + 1
    await record_successful_message(
        session, user_id=sender.id, marketplace_id=marketplace_id, body=body
    )
    await session.flush()
    return message


async def log_mod(
    session: AsyncSession,
    *,
    actor_id: UUID | None,
    marketplace_id: UUID | None,
    action: str,
    target_type: str,
    target_id: str,
    metadata: dict | None = None,
) -> None:
    session.add(
        MarketplaceCommunityModerationLog(
            id=uuid4(),
            actor_id=actor_id,
            marketplace_id=marketplace_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            metadata_=metadata or {},
        )
    )


async def hub_stats(session: AsyncSession, marketplace: Marketplace) -> tuple[int, int]:
    member_count = int(
        await session.scalar(
            select(func.count())
            .select_from(MarketplaceCommunityMembership)
            .where(MarketplaceCommunityMembership.marketplace_id == marketplace.id)
        )
        or 0
    )
    message_count = int(
        await session.scalar(
            select(func.coalesce(func.sum(MarketplaceCommunityChannel.message_count), 0))
            .select_from(MarketplaceCommunityChannel)
            .where(MarketplaceCommunityChannel.marketplace_id == marketplace.id)
        )
        or 0
    )
    return member_count, message_count
