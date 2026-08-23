"""Replace VIP with Basic (free); update Premium and Enterprise pricing.

Revision ID: 019
Revises: 018
"""

from alembic import op
import sqlalchemy as sa

revision = "019"
down_revision = "018"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        sa.text(
            """
            INSERT INTO subscription_plans (
                id, code, name, description, price_mad, price_mad_yearly,
                billing_period_days, features, is_active, tier_level, sort_order, trial_days,
                stripe_product_id, stripe_price_id_monthly, stripe_price_id_yearly, created_at
            )
            SELECT
                gen_random_uuid(), 'basic', 'Basic',
                'Free forever — list your business and reach local buyers',
                0, 0, 30,
                '["Business storefront", "Product and service listings", "Messaging with buyers", "Standard search visibility"]'::jsonb,
                true, 0, 0, 0, '', '', '', now()
            WHERE NOT EXISTS (SELECT 1 FROM subscription_plans WHERE code = 'basic')
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE subscriptions s
            SET plan_id = p_premium.id
            FROM subscription_plans p_vip, subscription_plans p_premium
            WHERE s.plan_id = p_vip.id
              AND p_vip.code = 'vip'
              AND p_premium.code = 'premium'
              AND s.status IN ('active', 'trialing', 'past_due')
            """
        )
    )
    op.execute(
        sa.text(
            """
            UPDATE subscriptions s
            SET plan_id = p_basic.id, status = 'active'
            FROM subscription_plans p_vip, subscription_plans p_basic
            WHERE s.plan_id = p_vip.id
              AND p_vip.code = 'vip'
              AND p_basic.code = 'basic'
              AND s.status NOT IN ('active', 'trialing', 'past_due')
            """
        )
    )

    op.execute(sa.text("DELETE FROM subscription_plans WHERE code = 'vip'"))

    op.execute(
        sa.text(
            """
            UPDATE subscription_plans SET
                name = 'Premium',
                description = 'Featured placement, premium storefront, and advanced discovery tools',
                price_mad = 199,
                price_mad_yearly = 1999,
                tier_level = 1,
                sort_order = 1,
                trial_days = 7,
                features = '["Featured placement", "Premium badge", "Advanced analytics", "Priority verification", "Extra media uploads"]'::jsonb
            WHERE code = 'premium'
            """
        )
    )

    op.execute(
        sa.text(
            """
            UPDATE subscription_plans SET
                name = 'Enterprise',
                description = 'Maximum visibility, dedicated support, and enterprise-grade tools',
                price_mad = 499,
                price_mad_yearly = 3999,
                tier_level = 2,
                sort_order = 2,
                trial_days = 14,
                features = '["Top search placement", "Enterprise badge", "Full analytics suite", "Dedicated support", "Unlimited featured slots", "API access (coming soon)"]'::jsonb
            WHERE code = 'enterprise'
            """
        )
    )

    op.execute(
        sa.text(
            """
            INSERT INTO subscriptions (
                id, user_id, plan_id, status, current_period_start, current_period_end,
                provider, provider_reference, billing_interval, cancel_at_period_end, created_at
            )
            SELECT
                gen_random_uuid(),
                sp.user_id,
                bp.id,
                'active',
                now(),
                now() + interval '100 years',
                'system',
                'migration-basic-' || left(sp.user_id::text, 12),
                'monthly',
                false,
                now()
            FROM seller_profiles sp
            CROSS JOIN subscription_plans bp
            WHERE bp.code = 'basic'
              AND NOT EXISTS (
                  SELECT 1 FROM subscriptions s WHERE s.user_id = sp.user_id
              )
            """
        )
    )


def downgrade() -> None:
    pass
