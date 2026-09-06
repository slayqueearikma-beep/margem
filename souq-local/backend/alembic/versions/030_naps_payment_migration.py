"""Migrate billing from Stripe to NAPS — provider-neutral payment fields."""

from alembic import op
import sqlalchemy as sa

revision = "030"
down_revision = "014_disc_payments"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("dribex_service_payments", sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("dribex_service_payments", sa.Column("refunded_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("subscriptions", sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True))

    op.create_table(
        "payment_refunds",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("payment_id", sa.UUID(), sa.ForeignKey("dribex_service_payments.id", ondelete="CASCADE"), nullable=False),
        sa.Column("provider", sa.String(length=40), nullable=False),
        sa.Column("provider_refund_id", sa.String(length=160), server_default="", nullable=False),
        sa.Column("amount_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(length=8), server_default="mad", nullable=False),
        sa.Column("status", sa.String(length=32), server_default="pending", nullable=False),
        sa.Column("reason", sa.Text(), server_default="", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_payment_refunds_payment_id", "payment_refunds", ["payment_id"])

    # Historical Stripe records remain read-only; new payments use provider=naps.
    op.execute(
        """
        UPDATE dribex_service_payments
        SET metadata = COALESCE(metadata, '{}'::jsonb) || '{"historical_provider":"stripe"}'::jsonb
        WHERE provider = 'stripe'
        """
    )


def downgrade() -> None:
    op.drop_index("ix_payment_refunds_payment_id", table_name="payment_refunds")
    op.drop_table("payment_refunds")
    op.drop_column("subscriptions", "cancelled_at")
    op.drop_column("dribex_service_payments", "refunded_at")
    op.drop_column("dribex_service_payments", "paid_at")
