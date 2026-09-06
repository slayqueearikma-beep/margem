"""User profile photograph fields and media object tracking."""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "029"
down_revision: Union[str, None] = "028"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("profile_photo_url", sa.String(length=512), server_default="", nullable=False),
    )
    op.create_table(
        "user_media_objects",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("blob_key", sa.String(length=512), nullable=False),
        sa.Column("public_url", sa.String(length=512), server_default="", nullable=False),
        sa.Column("purpose", sa.String(length=40), nullable=False),
        sa.Column("content_type", sa.String(length=64), server_default="", nullable=False),
        sa.Column("bytes_size", sa.Integer(), server_default="0", nullable=False),
        sa.Column("status", sa.String(length=24), server_default="active", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_media_objects_user_id", "user_media_objects", ["user_id"])
    op.create_index("ix_user_media_objects_blob_key", "user_media_objects", ["blob_key"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_user_media_objects_blob_key", table_name="user_media_objects")
    op.drop_index("ix_user_media_objects_user_id", table_name="user_media_objects")
    op.drop_table("user_media_objects")
    op.drop_column("users", "profile_photo_url")
