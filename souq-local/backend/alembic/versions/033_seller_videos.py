"""Add seller_videos table for premium short-form listings."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "033"
down_revision = "032"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "seller_videos",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "seller_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("video_url", sa.String(length=512), nullable=False, server_default=""),
        sa.Column("duration_seconds", sa.Numeric(8, 3, asdecimal=False), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False, server_default=""),
        sa.Column("caption", sa.Text(), nullable=False, server_default=""),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("ix_seller_videos_seller_id", "seller_videos", ["seller_id"])


def downgrade() -> None:
    op.drop_index("ix_seller_videos_seller_id", table_name="seller_videos")
    op.drop_table("seller_videos")
