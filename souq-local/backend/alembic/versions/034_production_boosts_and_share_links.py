"""Production boost packages, share links for QR, seller_pro pricing."""

from alembic import op

revision = "034"
down_revision = "033"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS share_links (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            token VARCHAR(32) NOT NULL UNIQUE,
            resource_type VARCHAR(32) NOT NULL,
            resource_id UUID NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT true,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now()
        )
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_share_links_token ON share_links (token)"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_share_links_resource ON share_links (resource_type, resource_id)"
    )

    op.execute(
        """
        INSERT INTO advertising_packages (id, code, name, description, placement_type, price_mad, duration_days, is_active)
        VALUES
          (gen_random_uuid(), 'boost_24h', 'Boost 24 hours',
           'Increase storefront visibility for 24 hours.',
           'sponsored_listing', 10.00, 1, true),
          (gen_random_uuid(), 'boost_3d', 'Boost 3 days',
           'Increase storefront visibility for 3 days.',
           'sponsored_listing', 25.00, 3, true),
          (gen_random_uuid(), 'boost_7d', 'Boost 7 days',
           'Increase storefront visibility for 7 days.',
           'sponsored_listing', 49.00, 7, true),
          (gen_random_uuid(), 'boost_30d', 'Boost 30 days',
           'Increase storefront visibility for 30 days.',
           'sponsored_listing', 99.00, 30, true)
        ON CONFLICT (code) DO UPDATE SET
          name = EXCLUDED.name,
          description = EXCLUDED.description,
          price_mad = EXCLUDED.price_mad,
          duration_days = EXCLUDED.duration_days,
          is_active = EXCLUDED.is_active;
        """
    )

    op.execute(
        """
        UPDATE subscription_plans
        SET price_mad = 99.00,
            name = 'Dribex Pro',
            description = 'Unlimited seller videos, featured placement, premium badge, analytics'
        WHERE code = 'seller_pro';
        """
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS share_links CASCADE")
