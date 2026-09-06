"""Remove listing video columns and seller_videos table."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "043_remove_listing_video"
down_revision = "042_platform_ad_campaigns"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_table("seller_videos")
    op.drop_column("products", "video_url")
    op.drop_column("services", "video_url")


def downgrade() -> None:
    op.add_column(
        "services",
        sa.Column("video_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("video_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.create_table(
        "seller_videos",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id"), nullable=False),
        sa.Column("video_url", sa.String(length=512), server_default="", nullable=False),
        sa.Column("duration_seconds", sa.Numeric(8, 3), nullable=False),
        sa.Column("title", sa.String(length=160), server_default="", nullable=False),
        sa.Column("caption", sa.Text(), server_default="", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index("ix_seller_videos_seller_id", "seller_videos", ["seller_id"])
