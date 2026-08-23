"""City community chat REST + WebSocket API."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_current_user, get_current_user_optional, require_admin, require_verified_email
from app.database import get_db
from app.limiter import limiter
from app.models import User
from app.models.community import (
    City,
    CommunityChannel,
    CommunityMembership,
    CommunityMessage,
    CommunityMessageStatus,
    CommunityReportStatus,
    CommunityUserBlock,
    CommunityUserMute,
)
from app.schemas.community import (
    CityCreate,
    CityOut,
    CommunityBanCreate,
    CommunityBlockCreate,
    CommunityChannelOut,
    CommunityDiscoverOut,
    CommunityJoinRequest,
    CommunityMessageCreate,
    CommunityMessageEdit,
    CommunityMessageOut,
    CommunityMuteCreate,
    CommunityReactionCreate,
    CommunityReportCreate,
)
from app.services.community_chat import (
    create_city_with_channels,
    delete_city_community,
    discover_cities,
    ensure_default_cities,
    ensure_membership,
    ensure_not_banned,
    get_channel,
    get_city_by_slug,
    join_city,
    list_messages,
    message_to_out,
    send_message,
    slugify_city,
    toggle_reaction,
    update_message,
)
from app.services.community_moderation import create_report, log_moderation
from app.services.community_websocket import community_ws_manager
from app.services.ws_ticket import community_audience, issue_ws_ticket, verify_ws_ticket

router = APIRouter(prefix="/community", tags=["community"])


def _city_out(city: City, *, is_member: bool = False, is_home_city: bool = False, online_count: int = 0) -> CityOut:
    return CityOut(
        id=city.id,
        slug=city.slug,
        name=city.name,
        description=city.description,
        is_active=city.is_active,
        member_count=city.member_count,
        message_count=city.message_count,
        online_count=online_count,
        is_member=is_member,
        is_home_city=is_home_city,
    )


async def _membership_flags(session: AsyncSession, user: User | None, city: City) -> tuple[bool, bool]:
    if user is None:
        return False, False
    membership = await session.scalar(
        select(CommunityMembership).where(
            CommunityMembership.user_id == user.id,
            CommunityMembership.city_id == city.id,
        )
    )
    if membership is None:
        return False, False
    return True, membership.is_home_city


@router.get("/cities", response_model=list[CityOut])
async def list_cities(
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> list[CityOut]:
    await ensure_default_cities(session)
    cities = list((await session.execute(select(City).where(City.is_active.is_(True)).order_by(City.name))).scalars())
    out: list[CityOut] = []
    for city in cities:
        is_member, is_home = await _membership_flags(session, user, city)
        out.append(
            _city_out(
                city,
                is_member=is_member,
                is_home_city=is_home,
                online_count=community_ws_manager.online_count(city.slug),
            )
        )
    return out


@router.get("/discover", response_model=CommunityDiscoverOut)
async def discover(
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> CommunityDiscoverOut:
    await ensure_default_cities(session)
    data = await discover_cities(session, viewer=user)

    def map_rows(rows: list[dict]) -> list[CityOut]:
        return [
            _city_out(
                row["city"],
                is_member=row["is_member"],
                is_home_city=row["is_home_city"],
                online_count=community_ws_manager.online_count(row["city"].slug),
            )
            for row in rows
        ]

    return CommunityDiscoverOut(
        trending=map_rows(data["trending"]),
        most_active=map_rows(data["most_active"]),
        fastest_growing=map_rows(data["fastest_growing"]),
    )


@router.post("/admin/cities", response_model=CityOut, status_code=status.HTTP_201_CREATED)
async def admin_create_city(
    payload: CityCreate,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> CityOut:
    slug = payload.slug or slugify_city(payload.name)
    existing = await session.scalar(select(City).where(City.slug == slug))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="City already exists")

    city = await create_city_with_channels(
        session, slug=slug, name=payload.name, description=payload.description
    )
    await log_moderation(
        session,
        actor_id=admin.id,
        action="create_city",
        target_type="city",
        target_id=str(city.id),
        metadata={"slug": slug},
    )
    await session.commit()
    return _city_out(city)


@router.delete("/admin/cities/{slug}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_city(
    slug: str,
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> None:
    city = await session.scalar(select(City).where(City.slug == slug))
    if city is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="City not found")
    await delete_city_community(session, city, actor_id=admin.id)
    await session.commit()


@router.get("/cities/{slug}", response_model=CityOut)
async def get_city(
    slug: str,
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> CityOut:
    await ensure_default_cities(session)
    city = await get_city_by_slug(session, slug)
    is_member, is_home = await _membership_flags(session, user, city)
    return _city_out(
        city,
        is_member=is_member,
        is_home_city=is_home,
        online_count=community_ws_manager.online_count(city.slug),
    )


@router.post("/cities/{slug}/join", response_model=CityOut)
async def join_city_endpoint(
    slug: str,
    payload: CommunityJoinRequest,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> CityOut:
    await ensure_default_cities(session)
    city = await get_city_by_slug(session, slug)
    await join_city(session, user=user, city=city, is_home_city=payload.is_home_city)
    await session.commit()
    return _city_out(city, is_member=True, is_home_city=payload.is_home_city)


@router.get("/cities/{slug}/channels", response_model=list[CommunityChannelOut])
async def list_city_channels(
    slug: str,
    user: User | None = Depends(get_current_user_optional),
    session: AsyncSession = Depends(get_db),
) -> list[CommunityChannelOut]:
    await ensure_default_cities(session)
    city = await get_city_by_slug(session, slug)
    channels = list(
        (
            await session.execute(
                select(CommunityChannel)
                .where(CommunityChannel.city_id == city.id, CommunityChannel.is_active.is_(True))
                .order_by(CommunityChannel.name)
            )
        )
        .scalars()
        .all()
    )
    return [
        CommunityChannelOut(
            id=ch.id,
            city_id=ch.city_id,
            category=ch.category.value,
            name=ch.name,
            description=ch.description,
            message_count=ch.message_count,
            is_active=ch.is_active,
        )
        for ch in channels
    ]


@router.get("/channels/{channel_id}/messages", response_model=list[CommunityMessageOut])
async def get_channel_messages(
    channel_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    limit: int = Query(default=50, ge=1, le=100),
    before_id: UUID | None = None,
    verified_only: bool = False,
    trusted_only: bool = False,
    q: str | None = Query(default=None, max_length=120),
) -> list[CommunityMessageOut]:
    channel = await get_channel(session, channel_id)
    return await list_messages(
        session,
        channel=channel,
        viewer=user,
        limit=limit,
        before_id=before_id,
        verified_only=verified_only,
        trusted_only=trusted_only,
        q=q,
    )


@router.post("/channels/{channel_id}/messages", response_model=CommunityMessageOut, status_code=status.HTTP_201_CREATED)
@limiter.limit("30/minute")
async def post_channel_message(
    request: Request,
    channel_id: UUID,
    payload: CommunityMessageCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> CommunityMessageOut:
    channel = await get_channel(session, channel_id)
    city = await session.get(City, channel.city_id)
    message = await send_message(session, channel=channel, sender=user, payload=payload)
    await session.commit()
    out = await message_to_out(session, message, viewer_id=user.id)
    await community_ws_manager.broadcast_channel(
        channel.id,
        {"type": "message.new", "payload": out.model_dump(mode="json")},
    )
    return out


@router.patch("/messages/{message_id}", response_model=CommunityMessageOut)
async def edit_message(
    message_id: UUID,
    payload: CommunityMessageEdit,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> CommunityMessageOut:
    message = await session.get(CommunityMessage, message_id)
    if message is None or message.sender_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    message = await update_message(session, message=message, editor=user, body=payload.body)
    await session.commit()
    out = await message_to_out(session, message, viewer_id=user.id)
    await community_ws_manager.broadcast_channel(
        message.channel_id,
        {"type": "message.edited", "payload": out.model_dump(mode="json")},
    )
    return out


@router.delete("/messages/{message_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_message(
    message_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    message = await session.get(CommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    is_owner = message.sender_id == user.id
    is_staff = user.role.value in {"admin", "support"}
    if not is_owner and not is_staff:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not allowed")

    message.status = CommunityMessageStatus.DELETED
    message.deleted_at = datetime.now(UTC)
    message.deleted_by_id = user.id
    message.body = ""
    await log_moderation(
        session,
        actor_id=user.id,
        action="delete_message",
        target_type="message",
        target_id=str(message.id),
    )
    await session.commit()
    await community_ws_manager.broadcast_channel(
        message.channel_id,
        {"type": "message.deleted", "payload": {"id": str(message.id)}},
    )


@router.post("/messages/{message_id}/reactions", response_model=list)
async def react_to_message(
    message_id: UUID,
    payload: CommunityReactionCreate,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> list:
    message = await session.get(CommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    channel = await get_channel(session, message.channel_id)
    await ensure_not_banned(session, city_id=channel.city_id, user_id=user.id)
    await ensure_membership(session, city_id=channel.city_id, user_id=user.id)
    reactions = await toggle_reaction(session, message=message, user=user, emoji=payload.emoji)
    await session.commit()
    await community_ws_manager.broadcast_channel(
        message.channel_id,
        {
            "type": "message.reaction",
            "payload": {"message_id": str(message.id), "reactions": [r.model_dump() for r in reactions]},
        },
    )
    return reactions


@router.post("/messages/{message_id}/report", status_code=status.HTTP_201_CREATED)
async def report_message(
    message_id: UUID,
    payload: CommunityReportCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    message = await session.get(CommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    report = await create_report(
        session,
        message=message,
        reporter=user,
        reason=payload.reason,
        details=payload.details,
    )
    await session.commit()
    return {"id": str(report.id), "status": report.status.value}


@router.post("/users/block", status_code=status.HTTP_201_CREATED)
async def block_user(
    payload: CommunityBlockCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    if payload.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot block yourself")
    existing = await session.scalar(
        select(CommunityUserBlock).where(
            CommunityUserBlock.blocker_id == user.id,
            CommunityUserBlock.blocked_id == payload.user_id,
        )
    )
    if existing is None:
        session.add(
            CommunityUserBlock(
                blocker_id=user.id,
                blocked_id=payload.user_id,
            )
        )
        await session.commit()
    return {"status": "blocked"}


@router.post("/users/mute", status_code=status.HTTP_201_CREATED)
async def mute_user(
    payload: CommunityMuteCreate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> dict:
    if payload.user_id == user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot mute yourself")
    existing = await session.scalar(
        select(CommunityUserMute).where(
            CommunityUserMute.muter_id == user.id,
            CommunityUserMute.muted_id == payload.user_id,
        )
    )
    if existing is None:
        session.add(
            CommunityUserMute(
                muter_id=user.id,
                muted_id=payload.user_id,
            )
        )
        await session.commit()
    return {"status": "muted"}


@router.post("/messages/{message_id}/pin", response_model=CommunityMessageOut)
async def pin_message(
    message_id: UUID,
    user: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
) -> CommunityMessageOut:
    message = await session.get(CommunityMessage, message_id)
    if message is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")
    await session.execute(
        update(CommunityMessage)
        .where(CommunityMessage.channel_id == message.channel_id)
        .values(is_pinned=False)
    )
    message.is_pinned = True
    await session.commit()
    out = await message_to_out(session, message, viewer_id=user.id)
    await community_ws_manager.broadcast_channel(
        message.channel_id,
        {"type": "message.pinned", "payload": out.model_dump(mode="json")},
    )
    return out


@router.get("/admin/reports")
async def list_reports(
    admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_db),
    status_filter: str = Query(default="open"),
) -> list[dict]:
    from app.models.community import CommunityReport

    stmt = select(CommunityReport).order_by(CommunityReport.created_at.desc()).limit(100)
    if status_filter:
        stmt = stmt.where(CommunityReport.status == CommunityReportStatus(status_filter))
    reports = list((await session.execute(stmt)).scalars().all())
    return [
        {
            "id": str(r.id),
            "message_id": str(r.message_id),
            "reason": r.reason,
            "status": r.status.value,
            "created_at": r.created_at.isoformat(),
        }
        for r in reports
    ]


class WsTicketOut(BaseModel):
    ticket: str
    expires_in: int = 60


@router.post("/channels/{channel_id}/ws-ticket", response_model=WsTicketOut)
@limiter.limit("30/minute")
async def issue_community_ws_ticket(
    request: Request,
    channel_id: UUID,
    user: User = Depends(require_verified_email),
    session: AsyncSession = Depends(get_db),
) -> WsTicketOut:
    _ = request
    channel = await get_channel(session, channel_id)
    await ensure_not_banned(session, city_id=channel.city_id, user_id=user.id)
    await ensure_membership(session, city_id=channel.city_id, user_id=user.id)
    ticket = issue_ws_ticket(user_id=user.id, channel_id=channel_id, audience=community_audience())
    return WsTicketOut(ticket=ticket)


async def _ws_user_from_token(token: str, session: AsyncSession) -> User | None:
    from app.auth import resolve_user_from_access_token

    return await resolve_user_from_access_token(token, session)


@router.websocket("/ws")
async def community_websocket(
    websocket: WebSocket,
    channel_id: UUID,
    ticket: str = Query(default=""),
    city_slug: str = Query(default=""),
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
                audience=community_audience(),
            )
            user = await session.get(User, user_id)
        except HTTPException:
            await websocket.close(code=4401)
            return
        if user is None:
            await websocket.close(code=4401)
            return
        channel = await get_channel(session, channel_id)
        if channel is None:
            await websocket.close(code=4404)
            return
        try:
            await ensure_not_banned(session, city_id=channel.city_id, user_id=user.id)
            await ensure_membership(session, city_id=channel.city_id, user_id=user.id)
        except HTTPException:
            await websocket.close(code=4403)
            return
        slug = city_slug or (channel.city.slug if channel.city else "")

    await community_ws_manager.connect(
        websocket, channel_id=channel_id, user_id=user.id, city_slug=slug
    )
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text('{"type":"pong"}')
            elif data.startswith("typing:"):
                await community_ws_manager.broadcast_channel(
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
        await community_ws_manager.disconnect(
            websocket, channel_id=channel_id, user_id=user.id, city_slug=slug
        )
