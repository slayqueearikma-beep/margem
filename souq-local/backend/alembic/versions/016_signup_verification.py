"""Pre-registration signup OTP verification."""

from alembic import op
import sqlalchemy as sa

revision = "016"
down_revision = "015"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "signup_verifications",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=False, server_default=""),
        sa.Column("channel", sa.String(length=16), nullable=False),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column("proof_token_hash", sa.String(length=64), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_signup_verifications_email", "signup_verifications", ["email"])
    op.create_index("ix_signup_verifications_proof_token_hash", "signup_verifications", ["proof_token_hash"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_signup_verifications_proof_token_hash", table_name="signup_verifications")
    op.drop_index("ix_signup_verifications_email", table_name="signup_verifications")
    op.drop_table("signup_verifications")
