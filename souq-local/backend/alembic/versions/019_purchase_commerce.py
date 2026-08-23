"""Purchase commerce: product selling fields and orders.

Revision ID: 019
Revises: 018
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "019"
down_revision: Union[str, None] = "018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

purchase_order_status = postgresql.ENUM(
    "preparing",
    "ready",
    "delivered",
    "completed",
    "cancelled",
    name="purchaseorderstatus",
    create_type=False,
)
purchase_payment_status = postgresql.ENUM(
    "pending",
    "paid",
    "failed",
    "refunded",
    name="purchasepaymentstatus",
    create_type=False,
)
delivery_mode_type = postgresql.ENUM(
    "provider_delivery",
    "pickup_only",
    name="productdeliverymode",
    create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    for enum_type in (purchase_order_status, purchase_payment_status, delivery_mode_type):
        enum_type.create(bind, checkfirst=True)

    op.add_column(
        "products",
        sa.Column("is_purchasable", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )
    op.add_column(
        "products",
        sa.Column(
            "delivery_mode",
            delivery_mode_type,
            server_default="pickup_only",
            nullable=False,
        ),
    )
    op.add_column(
        "products",
        sa.Column("delivery_fee_mad", sa.Numeric(12, 2), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("delivery_eta", sa.String(length=120), server_default="", nullable=False),
    )
    op.add_column(
        "products",
        sa.Column("free_delivery_threshold_mad", sa.Numeric(12, 2), nullable=True),
    )
    op.add_column(
        "products",
        sa.Column("tax_enabled", sa.Boolean(), server_default=sa.text("false"), nullable=False),
    )

    op.create_table(
        "purchase_orders",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("order_number", sa.String(length=32), nullable=False, unique=True),
        sa.Column("buyer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("seller_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("seller_profiles.id"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("products.id"), nullable=False),
        sa.Column("product_name", sa.String(length=160), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("subtotal_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("delivery_fee_mad", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("tax_mad", sa.Numeric(12, 2), server_default="0", nullable=False),
        sa.Column("total_mad", sa.Numeric(12, 2), nullable=False),
        sa.Column("delivery_method", sa.String(length=32), nullable=False),
        sa.Column("buyer_name", sa.String(length=120), server_default="", nullable=False),
        sa.Column("buyer_phone", sa.String(length=32), server_default="", nullable=False),
        sa.Column("buyer_address", sa.Text(), server_default="", nullable=False),
        sa.Column(
            "payment_status",
            purchase_payment_status,
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "order_status",
            purchase_order_status,
            server_default="preparing",
            nullable=False,
        ),
        sa.Column("stripe_checkout_session_id", sa.String(length=255), server_default="", nullable=False),
        sa.Column("stripe_payment_intent_id", sa.String(length=255), server_default="", nullable=False),
        sa.Column("receipt_number", sa.String(length=40), server_default="", nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_purchase_orders_buyer_id", "purchase_orders", ["buyer_id"])
    op.create_index("ix_purchase_orders_seller_id", "purchase_orders", ["seller_id"])
    op.create_index("ix_purchase_orders_product_id", "purchase_orders", ["product_id"])
    op.create_index(
        "ix_purchase_orders_stripe_checkout_session_id",
        "purchase_orders",
        ["stripe_checkout_session_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_purchase_orders_stripe_checkout_session_id", table_name="purchase_orders")
    op.drop_index("ix_purchase_orders_product_id", table_name="purchase_orders")
    op.drop_index("ix_purchase_orders_seller_id", table_name="purchase_orders")
    op.drop_index("ix_purchase_orders_buyer_id", table_name="purchase_orders")
    op.drop_table("purchase_orders")

    op.drop_column("products", "tax_enabled")
    op.drop_column("products", "free_delivery_threshold_mad")
    op.drop_column("products", "delivery_eta")
    op.drop_column("products", "delivery_fee_mad")
    op.drop_column("products", "delivery_mode")
    op.drop_column("products", "is_purchasable")

    op.execute("DROP TYPE IF EXISTS productdeliverymode CASCADE")
    op.execute("DROP TYPE IF EXISTS purchasepaymentstatus CASCADE")
    op.execute("DROP TYPE IF EXISTS purchaseorderstatus CASCADE")
