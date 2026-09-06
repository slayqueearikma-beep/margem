"""Add service pricing models and min/max price fields."""

from alembic import op
import sqlalchemy as sa

revision = "015"
down_revision = "014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "services",
        sa.Column("pricing_model", sa.String(length=32), nullable=False, server_default="fixed_price"),
    )
    op.add_column(
        "services",
        sa.Column("price_min_mad", sa.Numeric(12, 2, asdecimal=False), nullable=True),
    )
    op.add_column(
        "services",
        sa.Column("price_max_mad", sa.Numeric(12, 2, asdecimal=False), nullable=True),
    )

    op.execute(
        """
        UPDATE services
        SET pricing_model = CASE
            WHEN price_negotiable THEN 'negotiable'
            WHEN price_mad IS NULL THEN 'request_quote'
            WHEN price_mad = 0 THEN 'free'
            ELSE 'fixed_price'
        END
        """
    )


def downgrade() -> None:
    op.drop_column("services", "price_max_mad")
    op.drop_column("services", "price_min_mad")
    op.drop_column("services", "pricing_model")
