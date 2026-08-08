"""City community chat business logic."""

from __future__ import annotations

import re
from datetime import UTC, datetime
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models import User
from app.models.community import (
    DEFAULT_CHANNEL_SPECS,
    City,
    CommunityChannel,
    CommunityChannelCategory,
    CommunityMembership,
    CommunityMessage,
    CommunityMessageStatus,
    CommunityReaction,
)
from app.schemas.community import (
    CityCreate,
    CommunityAttachmentIn,
    CommunityMessageCreate,
    CommunityMessageOut,
    CommunityReactionOut,
)
from app.services.community_moderation import (
    compute_spam_score,
    detect_language,
    ensure_not_banned,
    extract_hashtags,
    extract_mentions,
    is_blocked,
    is_duplicate_message,
    is_muted,
    log_moderation,
)
from app.services.community_trust import sender_profile
from app.services.notifications import notify_user
from app.services.upload_security import validate_media_url


def _escape_ilike(value: str) -> str:
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _validate_attachments(attachments: list[CommunityAttachmentIn], *, owner_user_id: UUID) -> list[dict]:
    validated: list[dict] = []
    for attachment in attachments:
        validate_media_url(
            attachment.url,
            owner_user_id=owner_user_id,
            container=settings.azure_storage_container,
            public_api_url=settings.public_api_url if settings.storage_backend == "local" else None,
        )
        validated.append(attachment.model_dump())
    return validated


def slugify_city(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")


async def ensure_membership(
    session: AsyncSession,
    *,
    city_id: UUID,
    user_id: UUID,
) -> CommunityMembership:
    membership = await session.scalar(
        select(CommunityMembership).where(
            CommunityMembership.city_id == city_id,
            CommunityMembership.user_id == user_id,
        )
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Join this city community before participating",
        )
    return membership


async def ensure_default_cities(session: AsyncSession) -> None:
    from sqlalchemy.exc import IntegrityError

    for city_name in settings.default_cities:
        slug = slugify_city(city_name)
        existing = await session.scalar(select(City).where(City.slug == slug))
        if existing is None:
            try:
                async with session.begin_nested():
                    await create_city_with_channels(
                        session,
                        slug=slug,
                        name=city_name,
                        description=f"MarGem community for {city_name}",
                    )
            except IntegrityError:
                continue
    await session.commit()


async def create_city_with_channels(
    session: AsyncSession,
    *,
    slug: str,
    name: str,
    description: str = "",
) -> City:
    city = City(
        id=uuid4(),
        slug=slug,
        name=name,
        description=description,
        is_active=True,
    )
    session.add(city)
    await session.flush()

    for category, channel_name, channel_desc in DEFAULT_CHANNEL_SPECS:
        session.add(
            CommunityChannel(
                id=uuid4(),
                city_id=city.id,
                category=category,
                name=channel_name,
                description=channel_desc,
            )
        )
    return city


async def get_city_by_slug(session: AsyncSession, slug: str) -> City:
    city = await session.scalar(select(City).where(City.slug == slug, City.is_active.is_(True)))
    if city is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="City not found")
    return city


async def join_city(
    session: AsyncSession,
    *,
    user: User,
    city: City,
    is_home_city: bool = False,
) -> CommunityMembership:
    await ensure_not_banned(session, city_id=city.id, user_id=user.id)

    membership = await session.scalar(
        select(CommunityMembership).where(
            CommunityMembership.user_id == user.id,
            CommunityMembership.city_id == city.id,
        )
    )
    if membership is not None:
        if is_home_city:
            membership.is_home_city = True
        return membership

    if is_home_city:
        await session.execute(
            update(CommunityMembership)
            .where(CommunityMembership.user_id == user.id)
            .values(is_home_city=False)
        )

    membership = CommunityMembership(
        id=uuid4(),
        user_id=user.id,
        city_id=city.id,
        is_home_city=is_home_city,
        notification_prefs={
            "replies": True,
            "mentions": True,
            "reactions": True,
            "pinned": True,
            "announcements": True,
            "trending": False,
        },
    )
    session.add(membership)
    city.member_count = (city.member_count or 0) + 1
    return membership


async def get_channel(session: AsyncSession, channel_id: UUID) -> CommunityChannel:
    channel = await session.scalar(
        select(CommunityChannel)
        .options(selectinload(CommunityChannel.city))
        .where(CommunityChannel.id == channel_id, CommunityChannel.is_active.is_(True))
    )
    if channel is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Channel not found")
    return channel


async def _reaction_summary(
    session: AsyncSession,
    message_id: UUID,
    viewer_id: UUID,
) -> list[CommunityReactionOut]:
    rows = await session.execute(
        select(CommunityReaction.emoji, func.count(), func.bool_or(CommunityReaction.user_id == viewer_id))
        .where(CommunityReaction.message_id == message_id)
        .group_by(CommunityReaction.emoji)
    )
    return [
        CommunityReactionOut(emoji=emoji, count=count, reacted_by_me=bool(mine))
        for emoji, count, mine in rows.all()
    ]


async def message_to_out(
    session: AsyncSession,
    message: CommunityMessage,
    *,
    viewer_id: UUID,
    thread_reply_count: int = 0,
) -> CommunityMessageOut:
    sender = await session.get(User, message.sender_id)
    if sender is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sender not found")

    profile = await sender_profile(session, sender)
    reactions = await _reaction_summary(session, message.id, viewer_id)

    return CommunityMessageOut(
        id=message.id,
        channel_id=message.channel_id,
        sender=profile,
        body=message.body if message.status != CommunityMessageStatus.DELETED else "",
        reply_to_id=message.reply_to_id,
        thread_root_id=message.thread_root_id,
        thread_reply_count=thread_reply_count,
        attachments=message.attachments or [],
        link_preview=message.link_preview,
        mentions=message.mentions or [],
        hashtags=message.hashtags or [],
        language=message.language or "",
        status=message.status.value,
        is_pinned=message.is_pinned,
        is_edited=message.edited_at is not None,
        reactions=reactions,
        created_at=message.created_at,
        edited_at=message.edited_at,
    )


async def list_messages(
    session: AsyncSession,
    *,
    channel: CommunityChannel,
    viewer: User,
    limit: int = 50,
    before_id: UUID | None = None,
    category: CommunityChannelCategory | None = None,
    verified_only: bool = False,
    trusted_only: bool = False,
    q: str | None = None,
) -> list[CommunityMessageOut]:
    await ensure_not_banned(session, city_id=channel.city_id, user_id=viewer.id)
    await ensure_membership(session, city_id=channel.city_id, user_id=viewer.id)

    stmt = (
        select(CommunityMessage)
        .where(
            CommunityMessage.channel_id == channel.id,
            CommunityMessage.status.in_(
                [CommunityMessageStatus.VISIBLE, CommunityMessageStatus.PENDING_MODERATION]
            ),
        )
        .order_by(CommunityMessage.created_at.desc())
        .limit(limit)
    )

    if before_id is not None:
        pivot = await session.get(CommunityMessage, before_id)
        if pivot is not None:
            stmt = stmt.where(CommunityMessage.created_at < pivot.created_at)

    if q:
        safe_q = _escape_ilike(q[:120])
        stmt = stmt.where(CommunityMessage.body.ilike(f"%{safe_q}%"))

    messages = list((await session.execute(stmt)).scalars().all())
    results: list[CommunityMessageOut] = []

    for message in messages:
        if await is_blocked(session, viewer.id, message.sender_id):
            continue
        if await is_muted(session, viewer.id, message.sender_id):
            continue

        sender = await session.get(User, message.sender_id)
        if sender is None:
            continue

        profile = await sender_profile(session, sender)
        if verified_only and not profile.is_verified:
            continue
        if trusted_only and profile.trust_score < 70:
            continue

        thread_count = 0
        if message.thread_root_id is None and message.reply_to_id is None:
            thread_count = await session.scalar(
                select(func.count())
                .select_from(CommunityMessage)
                .where(CommunityMessage.thread_root_id == message.id)
            ) or 0

        results.append(
            await message_to_out(
                session,
                message,
                viewer_id=viewer.id,
                thread_reply_count=thread_count,
            )
        )

    return results


async def send_message(
    session: AsyncSession,
    *,
    channel: CommunityChannel,
    sender: User,
    payload: CommunityMessageCreate,
) -> CommunityMessage:
    await ensure_not_banned(session, city_id=channel.city_id, user_id=sender.id)
    await ensure_membership(session, city_id=channel.city_id, user_id=sender.id)

    body = payload.body.strip()
    if not body and not payload.attachments:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty")

    attachments = _validate_attachments(payload.attachments, owner_user_id=sender.id)

    duplicate = await is_duplicate_message(
        session, channel_id=channel.id, sender_id=sender.id, body=body
    )
    spam_score, spam_reason = compute_spam_score(body, recent_duplicate=duplicate)

    reply_to: CommunityMessage | None = None
    thread_root_id: UUID | None = None
    if payload.reply_to_id:
        reply_to = await session.get(CommunityMessage, payload.reply_to_id)
        if reply_to is None or reply_to.channel_id != channel.id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reply target not found")
        thread_root_id = reply_to.thread_root_id or reply_to.id

    status_value = CommunityMessageStatus.VISIBLE
    moderation_reason = ""
    if spam_score >= 0.75:
        status_value = CommunityMessageStatus.PENDING_MODERATION
        moderation_reason = spam_reason or "spam"

    message = CommunityMessage(
        id=uuid4(),
        channel_id=channel.id,
        sender_id=sender.id,
        body=body,
        reply_to_id=payload.reply_to_id,
        thread_root_id=thread_root_id,
        attachments=attachments,
        mentions=payload.mentions or extract_mentions(body),
        hashtags=extract_hashtags(body),
        language=detect_language(body),
        status=status_value,
        moderation_reason=moderation_reason,
        spam_score=spam_score,
    )
    session.add(message)

    channel.message_count = (channel.message_count or 0) + 1
    city = await session.get(City, channel.city_id)
    if city is not None:
        city.message_count = (city.message_count or 0) + 1

    if reply_to is not None and reply_to.sender_id != sender.id:
        await notify_user(
            session,
            user_id=reply_to.sender_id,
            title=f"Reply in {channel.name}",
            body=body[:120],
            kind="community_reply",
            data={"channel_id": str(channel.id), "message_id": str(message.id)},
        )

    for mention in message.mentions or []:
        # Lightweight mention notifications for display names (best-effort).
        mentioned = await session.scalar(
            select(User).where(func.lower(User.display_name) == mention.lower())
        )
        if mentioned and mentioned.id != sender.id:
            await notify_user(
                session,
                user_id=mentioned.id,
                title=f"Mentioned in {channel.name}",
                body=body[:120],
                kind="community_mention",
                data={"channel_id": str(channel.id), "message_id": str(message.id)},
            )

    await session.flush()
    return message


async def update_message(
    session: AsyncSession,
    *,
    message: CommunityMessage,
    editor: User,
    body: str,
) -> CommunityMessage:
    channel = await get_channel(session, message.channel_id)
    await ensure_not_banned(session, city_id=channel.city_id, user_id=editor.id)
    await ensure_membership(session, city_id=channel.city_id, user_id=editor.id)

    cleaned = body.strip()
    if not cleaned:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Message cannot be empty")

    spam_score, spam_reason = compute_spam_score(cleaned, recent_duplicate=False)
    message.body = cleaned
    message.edited_at = datetime.now(UTC)
    message.spam_score = spam_score
    if spam_score >= 0.75:
        message.status = CommunityMessageStatus.PENDING_MODERATION
        message.moderation_reason = spam_reason or "spam"
    await session.flush()
    return message


async def toggle_reaction(
    session: AsyncSession,
    *,
    message: CommunityMessage,
    user: User,
    emoji: str,
) -> list[CommunityReactionOut]:
    existing = await session.scalar(
        select(CommunityReaction).where(
            CommunityReaction.message_id == message.id,
            CommunityReaction.user_id == user.id,
            CommunityReaction.emoji == emoji,
        )
    )
    if existing:
        await session.delete(existing)
    else:
        session.add(
            CommunityReaction(
                id=uuid4(),
                message_id=message.id,
                user_id=user.id,
                emoji=emoji,
            )
        )
        if message.sender_id != user.id:
            await notify_user(
                session,
                user_id=message.sender_id,
                title="New reaction",
                body=f"{user.display_name} reacted {emoji}",
                kind="community_reaction",
                data={"message_id": str(message.id)},
            )

    await session.flush()
    return await _reaction_summary(session, message.id, user.id)


async def delete_city_community(session: AsyncSession, city: City, *, actor_id: UUID) -> None:
    await log_moderation(
        session,
        actor_id=actor_id,
        action="delete_city",
        target_type="city",
        target_id=str(city.id),
        metadata={"slug": city.slug},
    )
    await session.delete(city)


async def discover_cities(session: AsyncSession, *, viewer: User | None = None) -> dict:
    active = list(
        (
            await session.execute(
                select(City).where(City.is_active.is_(True)).order_by(City.member_count.desc())
            )
        )
        .scalars()
        .all()
    )

    trending = sorted(active, key=lambda c: c.message_count, reverse=True)[:5]
    most_active = sorted(active, key=lambda c: c.member_count, reverse=True)[:5]
    fastest = sorted(active, key=lambda c: (c.message_count, c.member_count), reverse=True)[:5]

    async def with_flags(cities: list[City]) -> list[dict]:
        out = []
        for city in cities:
            is_member = False
            is_home = False
            if viewer:
                membership = await session.scalar(
                    select(CommunityMembership).where(
                        CommunityMembership.user_id == viewer.id,
                        CommunityMembership.city_id == city.id,
                    )
                )
                if membership:
                    is_member = True
                    is_home = membership.is_home_city
            out.append(
                {
                    "city": city,
                    "is_member": is_member,
                    "is_home_city": is_home,
                }
            )
        return out

    return {
        "trending": await with_flags(trending),
        "most_active": await with_flags(most_active),
        "fastest_growing": await with_flags(fastest),
    }
