"""Dribex Plus+ / DriverPro pricing and subscription audit events."""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "038"
down_revision: Union[str, None] = "037"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE subscriptionstatus ADD VALUE IF NOT EXISTS 'pending'")
    op.execute("ALTER TYPE subscriptionstatus ADD VALUE IF NOT EXISTS 'payment_failed'")

    op.create_table(
        "subscription_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column(
            "subscription_id",
            UUID(as_uuid=True),
            sa.ForeignKey("subscriptions.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("plan_code", sa.String(40), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("metadata", JSONB, nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_subscription_events_user_id", "subscription_events", ["user_id"])
    op.create_index("ix_subscription_events_subscription_id", "subscription_events", ["subscription_id"])
    op.create_index("ix_subscription_events_event_type", "subscription_events", ["event_type"])

    op.execute(
        """
        UPDATE subscription_plans
        SET name = 'Dribex Plus+',
            price_mad = 50,
            description = 'Buyer subscription — suppress promotional ads and show Plus+ badge.',
            features = '["promotional_ads_suppressed", "plus_plus_badge", "saved_searches_sync", "priority_support"]'::jsonb
        WHERE code = 'buyer_premium'
        """
    )
    op.execute(
        """
        UPDATE subscription_plans
        SET name = 'DriverPro',
            price_mad = 149,
            description = 'Seller subscription — ad-free access, up to 20 combined products/services, and video uploads.',
            features = '["promotional_ads_suppressed", "combined_listing_limit_20", "video_uploads", "featured_placement", "premium_badge"]'::jsonb
        WHERE code = 'seller_pro'
        """
    )


def downgrade() -> None:
    op.drop_index("ix_subscription_events_event_type", table_name="subscription_events")
    op.drop_index("ix_subscription_events_subscription_id", table_name="subscription_events")
    op.drop_index("ix_subscription_events_user_id", table_name="subscription_events")
    op.drop_table("subscription_events")
