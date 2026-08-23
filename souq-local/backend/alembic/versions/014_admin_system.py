"""Admin system: extended roles, audit fields, login logs, category ordering."""

from alembic import op

revision = "014"
down_revision = "013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'moderator'")
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'super_admin'")

    op.execute(
        """
        ALTER TABLE admin_audit_logs
          ADD COLUMN IF NOT EXISTS ip_address VARCHAR(64) NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS user_agent VARCHAR(255) NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS success BOOLEAN NOT NULL DEFAULT TRUE,
          ADD COLUMN IF NOT EXISTS previous_value JSONB,
          ADD COLUMN IF NOT EXISTS new_value JSONB
        """
    )

    op.execute(
        """
        CREATE TABLE IF NOT EXISTS admin_login_logs (
          id UUID PRIMARY KEY,
          user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          ip_address VARCHAR(64) NOT NULL DEFAULT '',
          user_agent VARCHAR(255) NOT NULL DEFAULT '',
          success BOOLEAN NOT NULL DEFAULT TRUE,
          failure_reason VARCHAR(120) NOT NULL DEFAULT '',
          created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_admin_login_logs_user_id ON admin_login_logs (user_id)"
    )

    op.execute(
        """
        ALTER TABLE categories
          ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE categories DROP COLUMN IF EXISTS sort_order")
    op.execute("DROP TABLE IF EXISTS admin_login_logs")
    op.execute(
        """
        ALTER TABLE admin_audit_logs
          DROP COLUMN IF EXISTS ip_address,
          DROP COLUMN IF EXISTS user_agent,
          DROP COLUMN IF EXISTS success,
          DROP COLUMN IF EXISTS previous_value,
          DROP COLUMN IF EXISTS new_value
        """
    )
