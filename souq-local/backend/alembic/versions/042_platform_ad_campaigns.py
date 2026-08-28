"""Extend platform advertisements into full manual ad campaigns."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "042_platform_ad_campaigns"
down_revision = "041_rewarded_ad_grants"
branch_labels = None
depends_on = None

_CAMPAIGN_STATUS = sa.Enum(
    "draft",
    "scheduled",
    "active",
    "paused",
    "expired",
    "completed",
    "cancelled",
    name="platformadcampaignstatus",
    create_type=False,
)
_PAYMENT_STATUS = sa.Enum(
    "pending",
    "paid",
    "cancelled",
    "refunded",
    name="platformadpaymentstatus",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    _CAMPAIGN_STATUS.create(bind, checkfirst=True)
    _PAYMENT_STATUS.create(bind, checkfirst=True)

    op.add_column(
        "platform_advertisements",
        sa.Column("advertiser_name", sa.String(200), nullable=False, server_default=""),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("campaign_name", sa.String(200), nullable=False, server_default=""),
    )
    op.add_column("platform_advertisements", sa.Column("description", sa.Text(), nullable=True))
    op.add_column("platform_advertisements", sa.Column("video_url", sa.String(2048), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column("contact_info", sa.String(500), nullable=False, server_default=""),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("placement", sa.String(64), nullable=False, server_default="homepage_top"),
    )
    op.add_column("platform_advertisements", sa.Column("starts_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("platform_advertisements", sa.Column("ends_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column(
            "status",
            _CAMPAIGN_STATUS,
            nullable=False,
            server_default="active",
        ),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("priority", sa.Integer(), nullable=False, server_default="5"),
    )
    op.add_column("platform_advertisements", sa.Column("max_impressions", sa.Integer(), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column("max_impressions_per_user_per_day", sa.Integer(), nullable=True),
    )
    op.add_column("platform_advertisements", sa.Column("min_interval_minutes", sa.Integer(), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column("impression_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("click_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column(
            "payment_status",
            _PAYMENT_STATUS,
            nullable=False,
            server_default="paid",
        ),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("payment_override", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column(
        "platform_advertisements",
        sa.Column("internal_notes", sa.Text(), nullable=False, server_default=""),
    )
    op.add_column("platform_advertisements", sa.Column("created_by_admin_id", UUID(as_uuid=True), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.add_column("platform_advertisements", sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("platform_advertisements", sa.Column("target_city", sa.String(100), nullable=True))
    op.add_column("platform_advertisements", sa.Column("target_category_slug", sa.String(100), nullable=True))
    op.add_column("platform_advertisements", sa.Column("target_listing_type", sa.String(20), nullable=True))
    op.add_column(
        "platform_advertisements",
        sa.Column("target_platform", sa.String(20), nullable=False, server_default="all"),
    )

    op.create_foreign_key(
        "fk_platform_advertisements_created_by_admin",
        "platform_advertisements",
        "users",
        ["created_by_admin_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_platform_advertisements_placement", "platform_advertisements", ["placement"])
    op.create_index("ix_platform_advertisements_status", "platform_advertisements", ["status"])
    op.create_index("ix_platform_advertisements_deleted_at", "platform_advertisements", ["deleted_at"])
    op.create_index(
        "ix_platform_advertisements_schedule",
        "platform_advertisements",
        ["starts_at", "ends_at"],
    )

    op.execute(
        """
        UPDATE platform_advertisements
        SET campaign_name = title,
            advertiser_name = 'Legacy',
            status = CASE WHEN is_active THEN 'active'::platformadcampaignstatus
                          ELSE 'paused'::platformadcampaignstatus END,
            payment_status = 'paid'::platformadpaymentstatus
        """
    )

    op.create_table(
        "ad_impressions",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "campaign_id",
            UUID(as_uuid=True),
            sa.ForeignKey("platform_advertisements.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("recorded_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("viewer_key", sa.String(128), nullable=False, server_default=""),
        sa.Column("placement", sa.String(64), nullable=False, server_default=""),
        sa.Column("platform", sa.String(20), nullable=False, server_default="web"),
        sa.Column("view_key", sa.String(128), nullable=False),
        sa.UniqueConstraint("campaign_id", "view_key", name="uq_ad_impressions_campaign_view_key"),
    )
    op.create_index("ix_ad_impressions_campaign_recorded", "ad_impressions", ["campaign_id", "recorded_at"])
    op.create_index(
        "ix_ad_impressions_campaign_viewer_day",
        "ad_impressions",
        ["campaign_id", "viewer_key", "recorded_at"],
    )

    op.create_table(
        "ad_clicks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "campaign_id",
            UUID(as_uuid=True),
            sa.ForeignKey("platform_advertisements.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("recorded_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("viewer_key", sa.String(128), nullable=False, server_default=""),
        sa.Column("placement", sa.String(64), nullable=False, server_default=""),
        sa.Column("platform", sa.String(20), nullable=False, server_default="web"),
        sa.Column("click_key", sa.String(128), nullable=False),
        sa.UniqueConstraint("campaign_id", "click_key", name="uq_ad_clicks_campaign_click_key"),
    )
    op.create_index("ix_ad_clicks_campaign_recorded", "ad_clicks", ["campaign_id", "recorded_at"])


def downgrade() -> None:
    op.drop_index("ix_ad_clicks_campaign_recorded", table_name="ad_clicks")
    op.drop_table("ad_clicks")
    op.drop_index("ix_ad_impressions_campaign_viewer_day", table_name="ad_impressions")
    op.drop_index("ix_ad_impressions_campaign_recorded", table_name="ad_impressions")
    op.drop_table("ad_impressions")

    op.drop_index("ix_platform_advertisements_schedule", table_name="platform_advertisements")
    op.drop_index("ix_platform_advertisements_deleted_at", table_name="platform_advertisements")
    op.drop_index("ix_platform_advertisements_status", table_name="platform_advertisements")
    op.drop_index("ix_platform_advertisements_placement", table_name="platform_advertisements")
    op.drop_constraint(
        "fk_platform_advertisements_created_by_admin",
        "platform_advertisements",
        type_="foreignkey",
    )

    for col in (
        "target_platform",
        "target_listing_type",
        "target_category_slug",
        "target_city",
        "deleted_at",
        "updated_at",
        "created_by_admin_id",
        "internal_notes",
        "payment_override",
        "payment_status",
        "click_count",
        "impression_count",
        "min_interval_minutes",
        "max_impressions_per_user_per_day",
        "max_impressions",
        "priority",
        "status",
        "ends_at",
        "starts_at",
        "placement",
        "contact_info",
        "video_url",
        "description",
        "campaign_name",
        "advertiser_name",
    ):
        op.drop_column("platform_advertisements", col)

    bind = op.get_bind()
    _PAYMENT_STATUS.drop(bind, checkfirst=True)
    _CAMPAIGN_STATUS.drop(bind, checkfirst=True)
