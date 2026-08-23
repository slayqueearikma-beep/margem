"""Phase 1 compliance — security event persistence and report moderation fields."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "031"
down_revision = "030"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "security_events",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("event_type", sa.String(length=80), nullable=False, index=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True),
        sa.Column("ip_address", sa.String(length=64), server_default="", nullable=False),
        sa.Column("metadata", postgresql.JSONB(astext_type=sa.Text()), server_default="{}", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_security_events_created_at", "security_events", ["created_at"])

    op.add_column("reports", sa.Column("reviewed_by_id", sa.UUID(), nullable=True))
    op.add_column("reports", sa.Column("resolution_notes", sa.Text(), server_default="", nullable=False))
    op.add_column("reports", sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True))
    op.create_foreign_key(
        "fk_reports_reviewed_by_id_users",
        "reports",
        "users",
        ["reviewed_by_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_reports_reviewed_by_id_users", "reports", type_="foreignkey")
    op.drop_column("reports", "updated_at")
    op.drop_column("reports", "resolution_notes")
    op.drop_column("reports", "reviewed_by_id")
    op.drop_index("ix_security_events_created_at", table_name="security_events")
    op.drop_table("security_events")
