from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.marketplace_community import MarketplacePostType


class MarketplaceCommunityHubOut(BaseModel):
    marketplace_id: UUID
    marketplace_slug: str
    marketplace_name: str
    member_count: int
    message_count: int
    online_count: int = 0
    is_member: bool = False


class MarketplaceCommunityChannelOut(BaseModel):
    id: UUID
    marketplace_id: UUID
    slug: str
    name: str
    description: str
    default_post_type: MarketplacePostType
    message_count: int
    is_active: bool
    display_order: int

    model_config = {"from_attributes": True}


class MarketplaceCommunitySenderOut(BaseModel):
    id: UUID
    display_name: str
    is_verified: bool = False
    trust_score: int = 50


class MarketplaceCommunityMessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=4000)
    post_type: MarketplacePostType = MarketplacePostType.GENERAL
    reply_to_id: UUID | None = None


class MarketplaceCommunityMessageEdit(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class MarketplaceCommunityMessageOut(BaseModel):
    id: UUID
    channel_id: UUID
    sender: MarketplaceCommunitySenderOut
    body: str
    post_type: MarketplacePostType
    reply_to_id: UUID | None = None
    status: str
    is_pinned: bool
    is_edited: bool
    created_at: datetime
    edited_at: datetime | None = None


class MarketplaceCommunityReportCreate(BaseModel):
    reason: str = Field(min_length=2, max_length=80)
    details: str = Field(default="", max_length=2000)


class MarketplaceCommunityBanCreate(BaseModel):
    user_id: UUID
    reason: str = Field(default="", max_length=500)
    expires_in_minutes: int | None = Field(default=None, ge=1, le=60 * 24 * 30)


class MarketplaceCommunityReportOut(BaseModel):
    id: UUID
    message_id: UUID
    reporter_id: UUID
    reason: str
    details: str
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}
