"""Seller custom marketplace name + Other Casablanca Markets bucket."""

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

revision: str = "037"
down_revision: Union[str, None] = "036"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

OTHER_MARKET = {
    "id": str(uuid4()),
    "slug": "other-casablanca-markets",
    "name": "Other Casablanca Markets",
    "description": "Casablanca commercial areas not yet listed as dedicated markets.",
    "known_for": "User-provided market or district names — verify before treating as official.",
    "address": "Casablanca",
    "district": "Casablanca",
    "city": "Casablanca",
    "latitude": 33.5731,
    "longitude": -7.5898,
    "display_order": 99,
}


def upgrade() -> None:
    op.add_column(
        "seller_profiles",
        sa.Column("custom_marketplace_name", sa.String(length=160), nullable=False, server_default=""),
    )
    op.alter_column("seller_profiles", "custom_marketplace_name", server_default=None)

    conn = op.get_bind()
    conn.execute(
        sa.text(
            """
            INSERT INTO marketplaces (
                id, slug, name, description, known_for, address, district, city,
                latitude, longitude, display_order, is_active
            )
            VALUES (
                :id, :slug, :name, :description, :known_for, :address, :district, :city,
                :latitude, :longitude, :display_order, true
            )
            ON CONFLICT (slug) DO NOTHING
            """
        ),
        OTHER_MARKET,
    )


def downgrade() -> None:
    conn = op.get_bind()
    conn.execute(
        sa.text("DELETE FROM marketplaces WHERE slug = :slug"),
        {"slug": OTHER_MARKET["slug"]},
    )
    op.drop_column("seller_profiles", "custom_marketplace_name")
