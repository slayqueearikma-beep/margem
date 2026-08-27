"""Pydantic schemas for city community chat."""

from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class CityCreate(BaseModel):
    slug: str = Field(min_length=2, max_length=80)
    name: str = Field(min_length=2, max_length=120)
    description: str = Field(default="", max_length=2000)

    @field_validator("slug")
    @classmethod
    def normalize_slug(cls, value: str) -> str:
        slug = value.strip().lower().replace(" ", "-")
        if not slug.replace("-", "").isalnum():
            raise ValueError("slug must be alphanumeric with optional hyphens")
        return slug


class CityOut(BaseModel):
    id: UUID
    slug: str
    name: str
    description: str
    is_active: bool
    member_count: int
    message_count: int
    online_count: int = 0
    is_member: bool = False
    is_home_city: bool = False

    model_config = {"from_attributes": True}


class CommunityChannelOut(BaseModel):
    id: UUID
    city_id: UUID
    category: str
    name: str
    description: str
    message_count: int
    unread_count: int = 0
    is_active: bool

    model_config = {"from_attributes": True}


class CommunitySenderOut(BaseModel):
    id: UUID
    display_name: str
    avatar_url: str = ""
    role: str
    is_premium: bool
    show_plus_badge: bool = False
    is_verified: bool
    trust_score: int
    badges: list[str] = Field(default_factory=list)


class CommunityReactionOut(BaseModel):
    emoji: str
    count: int
    reacted_by_me: bool = False


class CommunityMessageOut(BaseModel):
    id: UUID
    channel_id: UUID
    sender: CommunitySenderOut
    body: str
    reply_to_id: UUID | None = None
    thread_root_id: UUID | None = None
    thread_reply_count: int = 0
    attachments: list[dict] = Field(default_factory=list)
    link_preview: dict | None = None
    mentions: list[str] = Field(default_factory=list)
    hashtags: list[str] = Field(default_factory=list)
    language: str = ""
    status: str
    is_pinned: bool
    is_edited: bool = False
    reactions: list[CommunityReactionOut] = Field(default_factory=list)
    created_at: datetime
    edited_at: datetime | None = None

    model_config = {"from_attributes": True}


class CommunityAttachmentIn(BaseModel):
    url: str = Field(min_length=1, max_length=2048)
    content_type: str = Field(default="image/jpeg", max_length=64)


class CommunityMessageCreate(BaseModel):
    body: str = Field(default="", max_length=4000)
    reply_to_id: UUID | None = None
    attachments: list[CommunityAttachmentIn] = Field(default_factory=list, max_length=4)
    mentions: list[str] = Field(default_factory=list)

    @field_validator("body")
    @classmethod
    def strip_body(cls, value: str) -> str:
        return value.strip()


class CommunityMessageEdit(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class CommunityReactionCreate(BaseModel):
    emoji: str = Field(min_length=1, max_length=32)


class CommunityReportCreate(BaseModel):
    reason: str = Field(min_length=2, max_length=80)
    details: str = Field(default="", max_length=2000)


class CommunityBlockCreate(BaseModel):
    user_id: UUID


class CommunityMuteCreate(BaseModel):
    user_id: UUID


class CommunityBanCreate(BaseModel):
    user_id: UUID
    reason: str = Field(default="", max_length=2000)
    expires_at: datetime | None = None


class CommunityJoinRequest(BaseModel):
    is_home_city: bool = False


class CommunityNotificationPrefs(BaseModel):
    replies: bool = True
    mentions: bool = True
    reactions: bool = True
    pinned: bool = True
    announcements: bool = True
    trending: bool = False


class CommunitySearchQuery(BaseModel):
    q: str = Field(min_length=1, max_length=120)


class CommunityDiscoverOut(BaseModel):
    trending: list[CityOut] = Field(default_factory=list)
    most_active: list[CityOut] = Field(default_factory=list)
    fastest_growing: list[CityOut] = Field(default_factory=list)


class CommunityTypingEvent(BaseModel):
    channel_id: UUID
    user_id: UUID
    display_name: str


class CommunityWsEvent(BaseModel):
    type: str
    payload: dict = Field(default_factory=dict)
