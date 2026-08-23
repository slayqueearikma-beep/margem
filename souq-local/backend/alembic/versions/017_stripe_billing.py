"""Stripe billing: business plans, customer IDs, webhook idempotency.

Revision ID: 017
Revises: 016
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "017"
down_revision = "016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("stripe_customer_id", sa.String(length=80), nullable=True))
    op.create_index("ix_users_stripe_customer_id", "users", ["stripe_customer_id"], unique=True)

    op.add_column(
        "subscription_plans",
        sa.Column("price_mad_yearly", sa.Numeric(12, 2), nullable=True),
    )
    op.add_column("subscription_plans", sa.Column("tier_level", sa.Integer(), server_default="1", nullable=False))
    op.add_column("subscription_plans", sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False))
    op.add_column("subscription_plans", sa.Column("trial_days", sa.Integer(), server_default="0", nullable=False))
    op.add_column(
        "subscription_plans",
        sa.Column("stripe_product_id", sa.String(length=80), server_default="", nullable=False),
    )
    op.add_column(
        "subscription_plans",
        sa.Column("stripe_price_id_monthly", sa.String(length=80), server_default="", nullable=False),
    )
    op.add_column(
        "subscription_plans",
        sa.Column("stripe_price_id_yearly", sa.String(length=80), server_default="", nullable=False),
    )

    op.add_column(
        "subscriptions",
        sa.Column("stripe_subscription_id", sa.String(length=80), nullable=True),
    )
    op.add_column(
        "subscriptions",
        sa.Column("billing_interval", sa.String(length=20), server_default="monthly", nullable=False),
    )
    op.add_column(
        "subscriptions",
        sa.Column("cancel_at_period_end", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.create_index(
        "ix_subscriptions_stripe_subscription_id",
        "subscriptions",
        ["stripe_subscription_id"],
        unique=True,
    )

    op.create_table(
        "stripe_webhook_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("event_id", sa.String(length=80), nullable=False),
        sa.Column("event_type", sa.String(length=80), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("event_id", name="uq_stripe_webhook_event_id"),
    )

    # Replace legacy buyer/seller plans with business tiers (VIP / Premium / Enterprise).
    op.execute(sa.text("DELETE FROM subscriptions"))
    op.execute(sa.text("DELETE FROM subscription_plans"))
    op.execute(
        sa.text(
            """
            INSERT INTO subscription_plans (
                id, code, name, description, price_mad, price_mad_yearly,
                billing_period_days, features, is_active, tier_level, sort_order, trial_days,
                stripe_product_id, stripe_price_id_monthly, stripe_price_id_yearly, created_at
            ) VALUES
            (
                gen_random_uuid(), 'vip', 'VIP',
                'Enhanced visibility and priority placement for growing businesses',
                99, 990, 30,
                '["Priority listing placement", "VIP badge", "Basic analytics", "Email support"]'::jsonb,
                true, 1, 1, 7, '', '', '', now()
            ),
            (
                gen_random_uuid(), 'premium', 'Premium',
                'Featured placement, premium storefront, and advanced discovery tools',
                199, 1990, 30,
                '["Featured placement", "Premium badge", "Advanced analytics", "Priority verification", "Extra media uploads"]'::jsonb,
                true, 2, 2, 7, '', '', '', now()
            ),
            (
                gen_random_uuid(), 'enterprise', 'Enterprise',
                'Maximum visibility, dedicated support, and enterprise-grade tools',
                499, 4990, 30,
                '["Top search placement", "Enterprise badge", "Full analytics suite", "Dedicated support", "Unlimited featured slots", "API access (coming soon)"]'::jsonb,
                true, 3, 3, 14, '', '', '', now()
            )
            """
        )
    )


def downgrade() -> None:
    op.drop_table("stripe_webhook_events")
    op.drop_index("ix_subscriptions_stripe_subscription_id", table_name="subscriptions")
    op.drop_column("subscriptions", "cancel_at_period_end")
    op.drop_column("subscriptions", "billing_interval")
    op.drop_column("subscriptions", "stripe_subscription_id")
    op.drop_column("subscription_plans", "stripe_price_id_yearly")
    op.drop_column("subscription_plans", "stripe_price_id_monthly")
    op.drop_column("subscription_plans", "stripe_product_id")
    op.drop_column("subscription_plans", "trial_days")
    op.drop_column("subscription_plans", "sort_order")
    op.drop_column("subscription_plans", "tier_level")
    op.drop_column("subscription_plans", "price_mad_yearly")
    op.drop_index("ix_users_stripe_customer_id", table_name="users")
    op.drop_column("users", "stripe_customer_id")
