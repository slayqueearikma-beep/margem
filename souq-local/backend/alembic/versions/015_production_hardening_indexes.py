"""Production hardening indexes and constraints.

Revision ID: 015
Revises: 014
"""

from alembic import op

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS uq_subscriptions_active_user
        ON subscriptions (user_id)
        WHERE status = 'active'
        """
    )
    op.execute(
        """
        CREATE INDEX IF NOT EXISTS ix_subscriptions_user_status
        ON subscriptions (user_id, status)
        """
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_subscriptions_user_status")
    op.execute("DROP INDEX IF EXISTS uq_subscriptions_active_user")
