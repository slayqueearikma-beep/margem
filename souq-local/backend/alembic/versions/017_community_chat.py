"""Alembic migration: city community chat tables."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "017"
down_revision = "016"
branch_labels = None
depends_on = None

CHANNEL_CATEGORIES = [
    "general",
    "marketplace",
    "recommendations",
    "questions",
    "events",
    "jobs",
    "housing",
    "services",
    "food",
    "transportation",
    "emergency_alerts",
    "announcements",
]


def upgrade() -> None:
    op.execute("CREATE TYPE communitychannelcategory AS ENUM (%s)" % ", ".join(f"'{c}'" for c in CHANNEL_CATEGORIES))
    op.execute("CREATE TYPE communitymessagestatus AS ENUM ('visible', 'pending_moderation', 'hidden', 'deleted')")
    op.execute("CREATE TYPE communityreportstatus AS ENUM ('open', 'reviewed', 'dismissed', 'actioned')")

    op.create_table(
        "cities",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("member_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("message_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cities_slug", "cities", ["slug"], unique=True)
    op.create_index("ix_cities_is_active", "cities", ["is_active"])

    op.create_table(
        "community_channels",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("city_id", sa.UUID(), nullable=False),
        sa.Column(
            "category",
            postgresql.ENUM(*CHANNEL_CATEGORIES, name="communitychannelcategory", create_type=False),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("message_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["city_id"], ["cities.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("city_id", "category", name="uq_community_channel_city_category"),
    )
    op.create_index("ix_community_channels_city_id", "community_channels", ["city_id"])
    op.create_index("ix_community_channels_category", "community_channels", ["category"])

    op.create_table(
        "community_memberships",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("city_id", sa.UUID(), nullable=False),
        sa.Column("is_home_city", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("notification_prefs", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("last_read_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["city_id"], ["cities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "city_id", name="uq_community_membership"),
    )
    op.create_index("ix_community_memberships_user_id", "community_memberships", ["user_id"])
    op.create_index("ix_community_memberships_city_id", "community_memberships", ["city_id"])

    op.create_table(
        "community_messages",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("channel_id", sa.UUID(), nullable=False),
        sa.Column("sender_id", sa.UUID(), nullable=False),
        sa.Column("body", sa.Text(), nullable=False, server_default=""),
        sa.Column("reply_to_id", sa.UUID(), nullable=True),
        sa.Column("thread_root_id", sa.UUID(), nullable=True),
        sa.Column("attachments", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("link_preview", postgresql.JSONB(), nullable=True),
        sa.Column("mentions", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("hashtags", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("language", sa.String(length=16), nullable=False, server_default=""),
        sa.Column(
            "status",
            postgresql.ENUM(
                "visible",
                "pending_moderation",
                "hidden",
                "deleted",
                name="communitymessagestatus",
                create_type=False,
            ),
            nullable=False,
            server_default="visible",
        ),
        sa.Column("moderation_reason", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("spam_score", sa.Float(), nullable=False, server_default="0"),
        sa.Column("is_pinned", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("edited_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_by_id", sa.UUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["channel_id"], ["community_channels.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["deleted_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reply_to_id"], ["community_messages.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["sender_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["thread_root_id"], ["community_messages.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_community_messages_channel_id", "community_messages", ["channel_id"])
    op.create_index("ix_community_messages_sender_id", "community_messages", ["sender_id"])
    op.create_index("ix_community_messages_channel_created", "community_messages", ["channel_id", "created_at"])
    op.create_index("ix_community_messages_thread_root", "community_messages", ["thread_root_id"])
    op.create_index("ix_community_messages_status", "community_messages", ["status"])

    op.create_table(
        "community_reactions",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("message_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("emoji", sa.String(length=32), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["community_messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("message_id", "user_id", "emoji", name="uq_community_reaction"),
    )
    op.create_index("ix_community_reactions_message_id", "community_reactions", ["message_id"])

    op.create_table(
        "community_reports",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("message_id", sa.UUID(), nullable=False),
        sa.Column("reporter_id", sa.UUID(), nullable=False),
        sa.Column("reason", sa.String(length=80), nullable=False),
        sa.Column("details", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "status",
            postgresql.ENUM(
                "open",
                "reviewed",
                "dismissed",
                "actioned",
                name="communityreportstatus",
                create_type=False,
            ),
            nullable=False,
            server_default="open",
        ),
        sa.Column("reviewed_by_id", sa.UUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["message_id"], ["community_messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_community_reports_message_id", "community_reports", ["message_id"])
    op.create_index("ix_community_reports_status", "community_reports", ["status"])

    for table, cols in [
        ("community_user_blocks", ("blocker_id", "blocked_id")),
        ("community_user_mutes", ("muter_id", "muted_id")),
    ]:
        op.create_table(
            table,
            sa.Column("id", sa.UUID(), nullable=False),
            sa.Column(cols[0], sa.UUID(), nullable=False),
            sa.Column(cols[1], sa.UUID(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
            sa.ForeignKeyConstraint([cols[0]], ["users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint([cols[1]], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint(cols[0], cols[1], name=f"uq_{table}"),
        )
        op.create_index(f"ix_{table}_{cols[0]}", table, [cols[0]])

    op.create_table(
        "community_city_bans",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("city_id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("banned_by_id", sa.UUID(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["banned_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["city_id"], ["cities.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("city_id", "user_id", name="uq_community_city_ban"),
    )
    op.create_index("ix_community_city_bans_city_id", "community_city_bans", ["city_id"])
    op.create_index("ix_community_city_bans_user_id", "community_city_bans", ["user_id"])

    op.create_table(
        "community_moderation_logs",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("actor_id", sa.UUID(), nullable=True),
        sa.Column("action", sa.String(length=80), nullable=False),
        sa.Column("target_type", sa.String(length=40), nullable=False, server_default=""),
        sa.Column("target_id", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("metadata", postgresql.JSONB(), nullable=False, server_default="{}"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_community_moderation_logs_actor_id", "community_moderation_logs", ["actor_id"])


def downgrade() -> None:
    op.drop_table("community_moderation_logs")
    op.drop_table("community_city_bans")
    op.drop_table("community_user_mutes")
    op.drop_table("community_user_blocks")
    op.drop_table("community_reports")
    op.drop_table("community_reactions")
    op.drop_table("community_messages")
    op.drop_table("community_memberships")
    op.drop_table("community_channels")
    op.drop_table("cities")
    op.execute("DROP TYPE IF EXISTS communityreportstatus")
    op.execute("DROP TYPE IF EXISTS communitymessagestatus")
    op.execute("DROP TYPE IF EXISTS communitychannelcategory")
