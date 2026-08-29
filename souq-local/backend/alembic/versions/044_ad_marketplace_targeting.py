"""Add marketplace targeting to platform advertisements."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "044_ad_marketplace_targeting"
down_revision = "043_remove_listing_video"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "platform_advertisements",
        sa.Column("target_marketplace_slug", sa.String(length=80), nullable=True),
    )
    op.create_index(
        "ix_platform_advertisements_target_marketplace_slug",
        "platform_advertisements",
        ["target_marketplace_slug"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_platform_advertisements_target_marketplace_slug",
        table_name="platform_advertisements",
    )
    op.drop_column("platform_advertisements", "target_marketplace_slug")
