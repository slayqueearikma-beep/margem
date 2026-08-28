"""Add video_url to services for DriverPro listing videos."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "040_services_video_url"
down_revision = "039_platform_advertisements"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "services",
        sa.Column("video_url", sa.String(length=512), server_default="", nullable=False),
    )


def downgrade() -> None:
    op.drop_column("services", "video_url")
