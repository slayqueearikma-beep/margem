"""Remove listing and seller video schema."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "043_remove_listing_video"
down_revision = "042_platform_ad_campaigns"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index("ix_seller_videos_seller_id", table_name="seller_videos")
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
        sa.Column("id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "seller_id",
            sa.dialects.postgresql.UUID(as_uuid=True),
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
