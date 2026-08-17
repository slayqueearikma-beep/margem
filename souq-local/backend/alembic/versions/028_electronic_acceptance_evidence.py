"""Electronic agreement evidence fields (Morocco Law 53-05 / DOC Art. 417-1–417-3)."""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "028"
down_revision: Union[str, None] = "027"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "legal_acceptances",
        sa.Column("document_hash", sa.String(length=64), server_default="", nullable=False),
    )
    op.add_column(
        "legal_acceptances",
        sa.Column("authentication_method", sa.String(length=32), server_default="bearer_session", nullable=False),
    )
    op.add_column(
        "legal_acceptances",
        sa.Column("source", sa.String(length=64), server_default="legal_accept", nullable=False),
    )
    op.add_column(
        "legal_acceptances",
        sa.Column("session_reference", sa.String(length=128), server_default="", nullable=False),
    )

    op.create_table(
        "subscription_agreement_records",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("subscription_id", sa.UUID(), nullable=True),
        sa.Column("plan_code", sa.String(length=40), nullable=False),
        sa.Column("plan_price_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("billing_period_days", sa.Integer(), nullable=False),
        sa.Column("policy_id", sa.String(length=64), server_default="subscription_terms", nullable=False),
        sa.Column("policy_version", sa.String(length=32), nullable=False),
        sa.Column("document_hash", sa.String(length=64), server_default="", nullable=False),
        sa.Column("language", sa.String(length=8), server_default="en", nullable=False),
        sa.Column(
            "accepted_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("ip_address", sa.String(length=64), server_default="", nullable=False),
        sa.Column("user_agent", sa.String(length=512), server_default="", nullable=False),
        sa.Column("authentication_method", sa.String(length=32), server_default="bearer_session", nullable=False),
        sa.Column("provider_reference", sa.String(length=120), server_default="", nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["subscription_id"], ["subscriptions.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_subscription_agreement_records_user_id",
        "subscription_agreement_records",
        ["user_id"],
    )
    op.create_index(
        "ix_subscription_agreement_records_subscription_id",
        "subscription_agreement_records",
        ["subscription_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_subscription_agreement_records_subscription_id", table_name="subscription_agreement_records")
    op.drop_index("ix_subscription_agreement_records_user_id", table_name="subscription_agreement_records")
    op.drop_table("subscription_agreement_records")

    op.drop_column("legal_acceptances", "session_reference")
    op.drop_column("legal_acceptances", "source")
    op.drop_column("legal_acceptances", "authentication_method")
    op.drop_column("legal_acceptances", "document_hash")
