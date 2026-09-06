"""Discovery-only payment architecture — Dribex service revenue tables only."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "014_disc_payments"
down_revision = "029"
branch_labels = None
depends_on = None

platform_payment_status = postgresql.ENUM(
    "pending",
    "success",
    "failed",
    "cancelled",
    "refunded",
    name="platformpaymentstatus",
    create_type=False,
)
advertising_campaign_status = postgresql.ENUM(
    "pending",
    "active",
    "expired",
    "cancelled",
    name="advertisingcampaignstatus",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    platform_payment_status.create(bind, checkfirst=True)
    advertising_campaign_status.create(bind, checkfirst=True)

    op.create_table(
        "dribex_service_payments",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="SET NULL"), nullable=True),
        sa.Column("service_type", sa.String(length=32), nullable=False),
        sa.Column("service_code", sa.String(length=64), nullable=False),
        sa.Column("amount_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(length=8), server_default="mad", nullable=False),
        sa.Column("status", platform_payment_status, server_default="pending", nullable=False),
        sa.Column("provider", sa.String(length=40), server_default="manual", nullable=False),
        sa.Column("provider_reference", sa.String(length=160), server_default="", nullable=False),
        sa.Column("metadata", postgresql.JSONB, server_default=sa.text("'{}'::jsonb"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_dribex_service_payments_user_id", "dribex_service_payments", ["user_id"])
    op.create_index("ix_dribex_service_payments_status", "dribex_service_payments", ["status"])
    op.create_index("ix_dribex_service_payments_provider_ref", "dribex_service_payments", ["provider_reference"])

    op.create_table(
        "payment_webhook_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("provider", sa.String(length=40), nullable=False),
        sa.Column("event_id", sa.String(length=160), nullable=False),
        sa.Column("payload_hash", sa.String(length=64), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.UniqueConstraint("provider", "event_id", name="uq_payment_webhook_provider_event"),
    )

    op.create_table(
        "advertising_packages",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("code", sa.String(length=64), nullable=False, unique=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), server_default="", nullable=False),
        sa.Column("placement_type", sa.String(length=40), nullable=False),
        sa.Column("price_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("duration_days", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )

    op.create_table(
        "advertising_campaigns",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id", ondelete="SET NULL"), nullable=True),
        sa.Column("package_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("advertising_packages.id"), nullable=False),
        sa.Column("payment_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dribex_service_payments.id", ondelete="SET NULL"), nullable=True),
        sa.Column("status", advertising_campaign_status, server_default="pending", nullable=False),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_advertising_campaigns_seller_id", "advertising_campaigns", ["seller_id"])
    op.create_index("ix_advertising_campaigns_status", "advertising_campaigns", ["status"])

    op.execute(
        """
        INSERT INTO advertising_packages (id, code, name, description, placement_type, price_mad, duration_days, is_active)
        VALUES
          (gen_random_uuid(), 'sponsored_listing_7d', 'Sponsored listing (7 days)',
           'Promote your storefront in discovery results for seven days.',
           'sponsored_listing', 149.00, 7, true),
          (gen_random_uuid(), 'promoted_product_7d', 'Promoted product (7 days)',
           'Boost a single product in search and category browsing for seven days.',
           'promoted_product', 79.00, 7, true),
          (gen_random_uuid(), 'featured_seller_30d', 'Featured seller (30 days)',
           'Featured placement on the buyer home discovery carousel for thirty days.',
           'featured_seller', 299.00, 30, true)
        ON CONFLICT (code) DO NOTHING
        """
    )


def downgrade() -> None:
    op.drop_index("ix_advertising_campaigns_status", table_name="advertising_campaigns")
    op.drop_index("ix_advertising_campaigns_seller_id", table_name="advertising_campaigns")
    op.drop_table("advertising_campaigns")
    op.drop_table("advertising_packages")
    op.drop_table("payment_webhook_events")
    op.drop_index("ix_dribex_service_payments_provider_ref", table_name="dribex_service_payments")
    op.drop_index("ix_dribex_service_payments_status", table_name="dribex_service_payments")
    op.drop_index("ix_dribex_service_payments_user_id", table_name="dribex_service_payments")
    op.drop_table("dribex_service_payments")
    op.execute("DROP TYPE IF EXISTS advertisingcampaignstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS platformpaymentstatus CASCADE")
