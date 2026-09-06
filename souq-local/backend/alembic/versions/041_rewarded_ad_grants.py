"""Rewarded advertisement grants for temporary feature unlocks."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "041_rewarded_ad_grants"
down_revision = "040_services_video_url"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rewarded_ad_sessions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("feature_code", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_rewarded_ad_sessions_user_id", "rewarded_ad_sessions", ["user_id"])
    op.create_index("ix_rewarded_ad_sessions_status", "rewarded_ad_sessions", ["status"])

    op.create_table(
        "rewarded_ad_grants",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("feature_code", sa.String(length=64), nullable=False),
        sa.Column("session_id", UUID(as_uuid=True), sa.ForeignKey("rewarded_ad_sessions.id", ondelete="SET NULL"), nullable=True),
        sa.Column("provider", sa.String(length=32), nullable=False, server_default="internal"),
        sa.Column("provider_reward_id", sa.String(length=128), nullable=True),
        sa.Column("granted_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("provider", "provider_reward_id", name="uq_rewarded_ad_grants_provider_reward"),
    )
    op.create_index("ix_rewarded_ad_grants_user_feature", "rewarded_ad_grants", ["user_id", "feature_code"])
    op.create_index("ix_rewarded_ad_grants_expires_at", "rewarded_ad_grants", ["expires_at"])


def downgrade() -> None:
    op.drop_index("ix_rewarded_ad_grants_expires_at", table_name="rewarded_ad_grants")
    op.drop_index("ix_rewarded_ad_grants_user_feature", table_name="rewarded_ad_grants")
    op.drop_table("rewarded_ad_grants")
    op.drop_index("ix_rewarded_ad_sessions_status", table_name="rewarded_ad_sessions")
    op.drop_index("ix_rewarded_ad_sessions_user_id", table_name="rewarded_ad_sessions")
    op.drop_table("rewarded_ad_sessions")
