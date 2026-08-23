"""Add marketplaces and per-marketplace category trees.

Revision ID: 019
Revises: 018
"""

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = "019"
down_revision: Union[str, None] = "018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

MARKETPLACES = [
    {
        "slug": "derb-ghallef",
        "name": "Derb Ghallef",
        "description": "Casablanca's electronics and mobile phone market.",
        "address": "Derb Ghallef",
        "district": "Derb Ghallef",
        "city": "Casablanca",
        "latitude": 33.5789,
        "longitude": -7.6100,
        "display_order": 1,
        "categories": [
            ("phones", "Phones", "Smartphones and accessories", "smartphone"),
            ("gaming", "Gaming", "Consoles and games", "sports_esports"),
            ("computers", "Computers", "Laptops and desktops", "computer"),
            ("networking", "Networking", "Routers and network gear", "router"),
            ("electronics", "Electronics", "General electronics", "devices"),
            ("repairs", "Repairs", "Phone and device repair", "build"),
        ],
    },
    {
        "slug": "derb-omar",
        "name": "Derb Omar",
        "description": "Hardware and construction supplies market.",
        "address": "Derb Omar",
        "district": "Derb Omar",
        "city": "Casablanca",
        "latitude": 33.5920,
        "longitude": -7.6180,
        "display_order": 2,
        "categories": [
            ("construction", "Construction", "Building materials", "construction"),
            ("hardware", "Hardware", "Tools and hardware", "hardware"),
            ("plumbing", "Plumbing", "Pipes and fittings", "plumbing"),
            ("electrical", "Electrical", "Electrical supplies", "electrical_services"),
        ],
    },
    {
        "slug": "9ri3a",
        "name": "9ri3a",
        "description": "Souk Al Qurayaa (القريعة) — auto parts and mechanics district.",
        "address": "Souk Al Qurayaa",
        "district": "القريعة",
        "city": "Casablanca",
        "latitude": 33.5650,
        "longitude": -7.5890,
        "display_order": 3,
        "categories": [
            ("toyota-parts", "Toyota Parts", "Toyota spare parts", "directions_car"),
            ("bmw-parts", "BMW Parts", "BMW spare parts", "directions_car"),
            ("mercedes-parts", "Mercedes Parts", "Mercedes spare parts", "directions_car"),
            ("tires", "Tires", "Tires and wheels", "tire_repair"),
            ("mechanics", "Mechanics", "Mechanics and garages", "car_repair"),
        ],
    },
]


def upgrade() -> None:
    op.create_table(
        "marketplaces",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("address", sa.String(length=255), nullable=False, server_default=""),
        sa.Column("district", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("city", sa.String(length=80), nullable=False, server_default="Casablanca"),
        sa.Column("latitude", sa.Float(), nullable=False, server_default="0"),
        sa.Column("longitude", sa.Float(), nullable=False, server_default="0"),
        sa.Column("cover_image_url", sa.String(length=512), nullable=False, server_default=""),
        sa.Column("logo_image_url", sa.String(length=512), nullable=False, server_default=""),
        sa.Column("opening_hours", JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_marketplaces_slug", "marketplaces", ["slug"], unique=True)
    op.create_index("ix_marketplaces_city", "marketplaces", ["city"])
    op.create_index("ix_marketplaces_is_active", "marketplaces", ["is_active"])
    op.create_index("ix_marketplaces_display_order", "marketplaces", ["display_order"])

    op.create_table(
        "marketplace_categories",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("marketplace_id", UUID(as_uuid=True), sa.ForeignKey("marketplaces.id", ondelete="CASCADE")),
        sa.Column(
            "parent_id",
            UUID(as_uuid=True),
            sa.ForeignKey("marketplace_categories.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("icon", sa.String(length=64), nullable=False, server_default="store"),
        sa.Column("banner_image_url", sa.String(length=512), nullable=False, server_default=""),
        sa.Column("display_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("marketplace_id", "slug", name="uq_marketplace_category_slug"),
    )
    op.create_index("ix_marketplace_categories_marketplace_id", "marketplace_categories", ["marketplace_id"])
    op.create_index("ix_marketplace_categories_parent_id", "marketplace_categories", ["parent_id"])
    op.create_index("ix_marketplace_categories_slug", "marketplace_categories", ["slug"])
    op.create_index("ix_marketplace_categories_display_order", "marketplace_categories", ["display_order"])
    op.create_index("ix_marketplace_categories_is_active", "marketplace_categories", ["is_active"])

    op.add_column(
        "seller_profiles",
        sa.Column("marketplace_id", UUID(as_uuid=True), nullable=True),
    )
    op.create_foreign_key(
        "fk_seller_profiles_marketplace_id",
        "seller_profiles",
        "marketplaces",
        ["marketplace_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_seller_profiles_marketplace_id", "seller_profiles", ["marketplace_id"])

    marketplaces_table = sa.table(
        "marketplaces",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("slug", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.Text),
        sa.column("address", sa.String),
        sa.column("district", sa.String),
        sa.column("city", sa.String),
        sa.column("latitude", sa.Float),
        sa.column("longitude", sa.Float),
        sa.column("display_order", sa.Integer),
        sa.column("is_active", sa.Boolean),
    )
    categories_table = sa.table(
        "marketplace_categories",
        sa.column("id", UUID(as_uuid=True)),
        sa.column("marketplace_id", UUID(as_uuid=True)),
        sa.column("name", sa.String),
        sa.column("slug", sa.String),
        sa.column("description", sa.Text),
        sa.column("icon", sa.String),
        sa.column("display_order", sa.Integer),
        sa.column("is_active", sa.Boolean),
    )

    for mp in MARKETPLACES:
        mp_id = uuid4()
        op.bulk_insert(
            marketplaces_table,
            [
                {
                    "id": mp_id,
                    "slug": mp["slug"],
                    "name": mp["name"],
                    "description": mp["description"],
                    "address": mp["address"],
                    "district": mp["district"],
                    "city": mp["city"],
                    "latitude": mp["latitude"],
                    "longitude": mp["longitude"],
                    "display_order": mp["display_order"],
                    "is_active": True,
                }
            ],
        )
        rows = []
        for order, (slug, name, desc, icon) in enumerate(mp["categories"]):
            rows.append(
                {
                    "id": uuid4(),
                    "marketplace_id": mp_id,
                    "name": name,
                    "slug": slug,
                    "description": desc,
                    "icon": icon,
                    "display_order": order,
                    "is_active": True,
                }
            )
        op.bulk_insert(categories_table, rows)


def downgrade() -> None:
    op.drop_index("ix_seller_profiles_marketplace_id", table_name="seller_profiles")
    op.drop_constraint("fk_seller_profiles_marketplace_id", "seller_profiles", type_="foreignkey")
    op.drop_column("seller_profiles", "marketplace_id")
    op.drop_table("marketplace_categories")
    op.drop_table("marketplaces")
