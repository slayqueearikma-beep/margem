"""Marketplace-specific community channels and spam protection.

Revision ID: 021
Revises: 020
"""

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "021"
down_revision: Union[str, None] = "020"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

CHANNEL_SEEDS = {
    "derb-ghallef": [
        ("general", "General", "Open discussion for Derb Ghallef", "general", 0),
        ("phones", "Phones", "Phones, accessories, and mobile deals", "deal", 1),
        ("gaming", "Gaming", "Consoles, games, and gaming gear", "deal", 2),
        ("deals", "Deals", "Share deals and price drops", "deal", 3),
        ("repairs", "Repairs", "Repair tips and trusted technicians", "seller_recommendation", 4),
    ],
    "derb-omar": [
        ("hardware", "Hardware", "Tools and hardware discussion", "general", 0),
        ("construction", "Construction", "Building materials and construction", "general", 1),
        ("wholesale", "Wholesale", "Bulk and wholesale offers", "deal", 2),
    ],
    "9ri3a": [
        ("toyota", "Toyota", "Toyota parts and mechanics", "general", 0),
        ("bmw", "BMW", "BMW parts and mechanics", "general", 1),
        ("mercedes", "Mercedes", "Mercedes parts and mechanics", "general", 2),
    ],
}


def upgrade() -> None:
    post_type = sa.Enum(
        "general",
        "question",
        "seller_recommendation",
        "deal",
        "announcement",
        "scam_report",
        name="marketplaceposttype",
    )
    message_status = sa.Enum(
        "visible",
        "pending_moderation",
        "hidden",
        "deleted",
        name="marketplacemessagestatus",
    )
    report_status = sa.Enum("open", "reviewed", "dismissed", "actioned", name="marketplacereportstatus")
    post_type.create(op.get_bind(), checkfirst=True)
    message_status.create(op.get_bind(), checkfirst=True)
    report_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "marketplace_community_channels",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="CASCADE")),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("default_post_type", post_type, nullable=False, server_default="general"),
        sa.Column("message_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("marketplace_id", "slug", name="uq_marketplace_community_channel_slug"),
    )
    op.create_index("ix_marketplace_community_channels_marketplace_id", "marketplace_community_channels", ["marketplace_id"])

    op.create_table(
        "marketplace_community_memberships",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="CASCADE")),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("last_read_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("user_id", "marketplace_id", name="uq_marketplace_community_membership"),
    )

    op.create_table(
        "marketplace_community_messages",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("channel_id", UUID(as_uuid=True), sa.ForeignKey("marketplace_community_channels.id", ondelete="CASCADE")),
        sa.Column("sender_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column("post_type", post_type, nullable=False, server_default="general"),
        sa.Column("reply_to_id", UUID(as_uuid=True), sa.ForeignKey("marketplace_community_messages.id", ondelete="SET NULL"), nullable=True),
        sa.Column("status", message_status, nullable=False, server_default="visible"),
        sa.Column("moderation_reason", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("spam_score", sa.Float(), nullable=False, server_default="0"),
        sa.Column("is_pinned", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_by_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_mp_community_messages_channel_created", "marketplace_community_messages", ["channel_id", "created_at"])

    op.create_table(
        "marketplace_community_reactions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id", UUID(as_uuid=True), sa.ForeignKey("marketplace_community_messages.id", ondelete="CASCADE")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("emoji", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("message_id", "user_id", "emoji", name="uq_marketplace_community_reaction"),
    )

    op.create_table(
        "marketplace_community_reports",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("message_id", UUID(as_uuid=True), sa.ForeignKey("marketplace_community_messages.id", ondelete="CASCADE")),
        sa.Column("reporter_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("reason", sa.String(length=80), nullable=False),
        sa.Column("details", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", report_status, nullable=False, server_default="open"),
        sa.Column("reviewed_by_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "marketplace_community_bans",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="CASCADE")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("banned_by_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("marketplace_id", "user_id", name="uq_marketplace_community_ban"),
    )

    op.create_table(
        "marketplace_community_spam_states",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE")),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="CASCADE")),
        sa.Column("violation_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_message_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_normalized_body", sa.Text(), nullable=False, server_default=""),
        sa.Column("muted_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("user_id", "marketplace_id", name="uq_marketplace_community_spam_state"),
    )

    op.create_table(
        "marketplace_community_moderation_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("actor_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="SET NULL"), nullable=True),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("target_type", sa.String(length=40), nullable=False, server_default=""),
        sa.Column("target_id", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("metadata", JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    conn = op.get_bind()
    marketplaces = conn.execute(sa.text("SELECT id, slug FROM marketplaces")).fetchall()
    channels_table = sa.table(
        "marketplace_community_channels",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("marketplace_id", UUID(as_uuid=True)),
        sa.column("slug", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.Text),
        sa.column("default_post_type", sa.String),
        sa.column("display_order", sa.Integer),
    )
    for mp_id, slug in marketplaces:
        specs = CHANNEL_SEEDS.get(slug, [("general", "General", f"Discussion for {slug}", "general", 0)])
        rows = []
        for ch_slug, name, desc, post_type, order in specs:
            rows.append(
                {
                    "id": uuid4(),
                    "marketplace_id": mp_id,
                    "slug": ch_slug,
                    "name": name,
                    "description": desc,
                    "default_post_type": post_type,
                    "display_order": order,
                }
            )
        if rows:
            op.bulk_insert(channels_table, rows)


def downgrade() -> None:
    op.drop_table("marketplace_community_moderation_logs")
    op.drop_table("marketplace_community_spam_states")
    op.drop_table("marketplace_community_bans")
    op.drop_table("marketplace_community_reports")
    op.drop_table("marketplace_community_reactions")
    op.drop_table("marketplace_community_messages")
    op.drop_table("marketplace_community_memberships")
    op.drop_table("marketplace_community_channels")
    sa.Enum(name="marketplacereportstatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="marketplacemessagestatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="marketplaceposttype").drop(op.get_bind(), checkfirst=True)
