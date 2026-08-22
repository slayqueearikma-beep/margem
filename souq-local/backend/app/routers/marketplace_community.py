"""Marketplace community REST + WebSocket API (isolated from city community)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, get_current_user_optional, require_staff, require_verified_email, resolve_user_from_access_token, _enforce_staff_mfa
from app.database import get_db
from app.limiter import limiter
from app.models import User
from app.models.marketplace_community import (
    MarketplaceCommunityBan,
    MarketplaceCommunityChannel,
    MarketplaceCommunityMembership,
    MarketplaceCommunityMessage,
    MarketplaceCommunityReport,
    MarketplaceMessageStatus,
    MarketplaceReportStatus,
)
from app.schemas.marketplace_community import (
    MarketplaceCommunityBanCreate,
    MarketplaceCommunityChannelOut,
    MarketplaceCommunityHubOut,
    MarketplaceCommunityMessageCreate,
    MarketplaceCommunityMessageEdit,
    MarketplaceCommunityMessageOut,
    MarketplaceCommunityReportCreate,
    MarketplaceCommunityReportOut,
)
from app.services.marketplace_community_chat import (
    ensure_membership,
    ensure_not_banned,
    get_channel,
    get_marketplace_by_slug,
    hub_stats,
    join_marketplace_community,
    list_messages,
    log_mod,
    message_to_out,
    send_message,
)
from app.services.marketplace_community_websocket import marketplace_community_ws_manager
from app.services.ws_ticket import issue_ws_ticket, marketplace_audience, verify_ws_ticket

router = APIRouter(prefix="/marketplaces", tags=["marketplace-community"])


class WsTicketOut(BaseModel):
    ticket: str
    expires_in: int = 60


async def _is_member(session: AsyncSession, user: User | None, marketplace_id: UUID) -> bool:
    if user is None:
        return False
    membership = await session.scalar(
        select(MarketplaceCommunityMembership).where(
            MarketplaceCommunityMembership.user_id == user.id,
            MarketplaceCommunityMembership.marketplace_id == marketplace_id,
        )
    )
    return membership is not None


@router.get("/{slug}/community", response_model=MarketplaceCommunityHubOut)
async def get_marketplace_community_hub(
    slug: str,
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCommunityHubOut:
    marketplace = await get_marketplace_by_slug(session, slug)
    member_count, message_count = await hub_stats(session, marketplace)
    await session.commit()
    return MarketplaceCommunityHubOut(
        marketplace_id=marketplace.id,
        marketplace_slug=marketplace.slug,
        marketplace_name=marketplace.name,
        member_count=member_count,
        message_count=message_count,
        online_count=marketplace_community_ws_manager.online_count(marketplace.slug),
        is_member=await _is_member(session, user, marketplace.id),
    )


@router.post("/{slug}/community/join", response_model=MarketplaceCommunityHubOut)
async def join_marketplace_community_endpoint(
    slug: str,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCommunityHubOut:
    marketplace = await get_marketplace_by_slug(session, slug)
    await join_marketplace_community(session, user=user, marketplace=marketplace)
    await session.commit()
    member_count, message_count = await hub_stats(session, marketplace)
    return MarketplaceCommunityHubOut(
        marketplace_id=marketplace.id,
        marketplace_slug=marketplace.slug,
        marketplace_name=marketplace.name,
        member_count=member_count,
        message_count=message_count,
        online_count=marketplace_community_ws_manager.online_count(marketplace.slug),
        is_member=True,
    )


@router.get("/{slug}/community/channels", response_model=list[MarketplaceCommunityChannelOut])
async def list_marketplace_community_channels(
    slug: str,
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCommunityChannelOut]:
    marketplace = await get_marketplace_by_slug(session, slug)
    await session.commit()
    rows = list(
        (
            await session.execute(
                select(MarketplaceCommunityChannel)
                .where(
                    MarketplaceCommunityChannel.marketplace_id == marketplace.id,
                    MarketplaceCommunityChannel.is_active.is_(True),
                )
                .order_by(MarketplaceCommunityChannel.display_order, MarketplaceCommunityChannel.name)
            )
        ).scalars()
    )
    return rows


@router.get("/community/channels/{channel_id}/messages", response_model=list[MarketplaceCommunityMessageOut])
async def list_marketplace_community_messages(
    channel_id: UUID,
    before_id: UUID | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCommunityMessageOut]:
    channel = await get_channel(session, channel_id)
    return await list_messages(session, channel=channel, viewer=user, limit=limit, before_id=before_id)


@router.post(
    "/community/channels/{channel_id}/messages",
    response_model=MarketplaceCommunityMessageOut,
    status_code=status.HTTP_201_CREATED,
)
@limiter.limit("30/minute")
async def post_marketplace_community_message(
    request: Request,
    channel_id: UUID,
    payload: MarketplaceCommunityMessageCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCommunityMessageOut:
    channel = await get_channel(session, channel_id)
    message = await send_message(session, channel=channel, sender=user, payload=payload)
    await session.commit()
    out = await message_to_out(session, message)
    await marketplace_community_ws_manager.broadcast_channel(
        channel.id,
        {"type": "message.new", "payload": out.model_dump(mode="json")},
    )
    return out


@router.patch("/community/messages/{message_id}", response_model=MarketplaceCommunityMessageOut)
async def edit_marketplace_community_message(
    message_id: UUID,
    payload: MarketplaceCommunityMessageEdit,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCommunityMessageOut:
    message = await session.get(MarketplaceCommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await get_channel(session, message.channel_id)
    await ensure_membership(session, marketplace_id=channel.marketplace_id, user_id=user.id)
    if message.sender_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")
    message.body = payload.body.strip()
    message.edited_at = datetime.now(UTC)
    await session.commit()
    out = await message_to_out(session, message)
    await marketplace_community_ws_manager.broadcast_channel(
        channel.id, {"type": "message.edited", "payload": out.model_dump(mode="json")}
    )
    return out


@router.delete("/community/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_marketplace_community_message(
    message_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    message = await session.get(MarketplaceCommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await get_channel(session, message.channel_id)
    from app.models import UserRole

    is_mod = user.role in {UserRole.ADMIN, UserRole.SUPPORT}
    if message.sender_id != user.id and not is_mod:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")
    if is_mod and message.sender_id != user.id:
        _enforce_staff_mfa(user)
    message.status = MarketplaceMessageStatus.DELETED
    message.deleted_at = datetime.now(UTC)
    message.deleted_by_id = user.id
    await log_mod(
        session,
        actor_id=user.id,
        marketplace_id=channel.marketplace_id,
        action="delete_message",
        target_type="message",
        target_id=str(message.id),
    )
    await session.commit()
    await marketplace_community_ws_manager.broadcast_channel(
        channel.id, {"type": "message.deleted", "payload": {"id": str(message.id)}}
    )


@router.post("/community/messages/{message_id}/report", status_code=status.HTTP_201_CREATED)
async def report_marketplace_community_message(
    message_id: UUID,
    payload: MarketplaceCommunityReportCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    message = await session.get(MarketplaceCommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await get_channel(session, message.channel_id)
    await ensure_membership(session, marketplace_id=channel.marketplace_id, user_id=user.id)
    report = MarketplaceCommunityReport(
        id=uuid4(),
        message_id=message.id,
        reporter_id=user.id,
        reason=payload.reason,
        details=payload.details,
        status=MarketplaceReportStatus.OPEN,
    )
    session.add(report)
    await log_mod(
        session,
        actor_id=user.id,
        marketplace_id=channel.marketplace_id,
        action="report_message",
        target_type="message",
        target_id=str(message.id),
        metadata={"reason": payload.reason},
    )
    await session.commit()
    return {"status": "reported"}


@router.post("/community/messages/{message_id}/pin", response_model=MarketplaceCommunityMessageOut)
async def pin_marketplace_community_message(
    message_id: UUID,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> MarketplaceCommunityMessageOut:
    message = await session.get(MarketplaceCommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await get_channel(session, message.channel_id)
    message.is_pinned = True
    await log_mod(
        session,
        actor_id=user.id,
        marketplace_id=channel.marketplace_id,
        action="pin_message",
        target_type="message",
        target_id=str(message.id),
    )
    await session.commit()
    out = await message_to_out(session, message)
    await marketplace_community_ws_manager.broadcast_channel(
        channel.id, {"type": "message.pinned", "payload": out.model_dump(mode="json")}
    )
    return out


@router.post("/{slug}/community/ban", status_code=status.HTTP_204_NO_CONTENT)
async def ban_from_marketplace_community(
    slug: str,
    payload: MarketplaceCommunityBanCreate,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> None:
    marketplace = await get_marketplace_by_slug(session, slug)
    expires_at = None
    if payload.expires_in_minutes is not None:
        expires_at = datetime.now(UTC) + timedelta(minutes=payload.expires_in_minutes)
    existing = await session.scalar(
        select(MarketplaceCommunityBan).where(
            MarketplaceCommunityBan.marketplace_id == marketplace.id,
            MarketplaceCommunityBan.user_id == payload.user_id,
        )
    )
    if existing is None:
        session.add(
            MarketplaceCommunityBan(
                id=uuid4(),
                marketplace_id=marketplace.id,
                user_id=payload.user_id,
                banned_by_id=user.id,
                reason=payload.reason,
                expires_at=expires_at,
            )
        )
    else:
        existing.reason = payload.reason
        existing.expires_at = expires_at
        existing.banned_by_id = user.id
    await log_mod(
        session,
        actor_id=user.id,
        marketplace_id=marketplace.id,
        action="ban_user",
        target_type="user",
        target_id=str(payload.user_id),
    )
    await session.commit()


@router.get("/community/admin/reports", response_model=list[MarketplaceCommunityReportOut])
async def list_marketplace_community_reports(
    marketplace_slug: str | None = None,
    user: User = Depends(require_staff),
    session: AsyncSession = Depends(get_db),
) -> list[MarketplaceCommunityReport]:
    stmt = select(MarketplaceCommunityReport).order_by(MarketplaceCommunityReport.created_at.desc()).limit(100)
    if marketplace_slug:
        marketplace = await get_marketplace_by_slug(session, marketplace_slug)
        channel_ids = list(
            (
                await session.execute(
                    select(MarketplaceCommunityChannel.id).where(
                        MarketplaceCommunityChannel.marketplace_id == marketplace.id
                    )
                )
            ).scalars()
        )
        if not channel_ids:
            return []
        message_ids = list(
            (
                await session.execute(
                    select(MarketplaceCommunityMessage.id).where(
                        MarketplaceCommunityMessage.channel_id.in_(channel_ids)
                    )
                )
            ).scalars()
        )
        if not message_ids:
            return []
        stmt = stmt.where(MarketplaceCommunityReport.message_id.in_(message_ids))
    return list((await session.execute(stmt)).scalars().all())


@router.post("/community/channels/{channel_id}/ws-ticket", response_model=WsTicketOut)
@limiter.limit("30/minute")
async def issue_marketplace_ws_ticket(
    request: Request,
    channel_id: UUID,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> WsTicketOut:
    _ = request
    channel = await get_channel(session, channel_id)
    await ensure_not_banned(session, marketplace_id=channel.marketplace_id, user_id=user.id)
    await ensure_membership(session, marketplace_id=channel.marketplace_id, user_id=user.id)
    ticket = issue_ws_ticket(user_id=user.id, channel_id=channel_id, audience=marketplace_audience())
    return WsTicketOut(ticket=ticket)


@router.websocket("/community/ws")
async def marketplace_community_websocket(
    websocket: WebSocket,
    channel_id: UUID,
    ticket: str = Query(default=""),
    marketplace_slug: str = Query(default=""),
) -> None:
    from app.database import SessionLocal

    async with SessionLocal() as session:
        user: User | None = None
        if not ticket.strip():
            await websocket.close(code=4401)
            return
        try:
            user_id = verify_ws_ticket(
                ticket.strip(),
                channel_id=channel_id,
                audience=marketplace_audience(),
            )
            user = await session.get(User, user_id)
        except HTTPException:
            await websocket.close(code=4401)
            return
        if user is None:
            await websocket.close(code=4401)
            return
        channel = await get_channel(session, channel_id)
        await ensure_not_banned(session, marketplace_id=channel.marketplace_id, user_id=user.id)
        await ensure_membership(session, marketplace_id=channel.marketplace_id, user_id=user.id)
        slug = marketplace_slug or "marketplace"

    await marketplace_community_ws_manager.connect(
        websocket, channel_id=channel_id, user_id=user.id, city_slug=slug
    )
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text('{"type":"pong"}')
            elif data.startswith("typing:"):
                await marketplace_community_ws_manager.broadcast_channel(
                    channel_id,
                    {
                        "type": "typing",
                        "payload": {
                            "channel_id": str(channel_id),
                            "user_id": str(user.id),
                            "display_name": user.display_name,
                        },
                    },
                )
    except WebSocketDisconnect:
        await marketplace_community_ws_manager.disconnect(
            websocket, channel_id=channel_id, user_id=user.id, city_slug=slug
        )
