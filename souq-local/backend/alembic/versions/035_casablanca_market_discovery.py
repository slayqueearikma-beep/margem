"""Casablanca market discovery: stall locations, known_for, new markets."""

from typing import Sequence, Union
from uuid import uuid4

import sqlalchemy as sa
from alembic import op

revision: str = "035"
down_revision: Union[str, None] = "034"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

NEW_MARKETS = [
    {
        "slug": "habous",
        "name": "Habous",
        "description": "Historic Habous quarter — traditional crafts, leather, clothing and Moroccan goods.",
        "known_for": "Traditional clothing, leather, handicrafts, spices and Moroccan gifts.",
        "address": "Quartier Habous",
        "district": "Habous",
        "latitude": 33.5775,
        "longitude": -7.6128,
        "display_order": 4,
        "categories": [
            ("traditional-clothing", "Traditional clothing", "Djellabas, caftans and traditional wear", "checkroom"),
            ("leather", "Leather", "Leather goods and bags", "shopping_bag"),
            ("handicrafts", "Handicrafts", "Artisan crafts and decor", "palette"),
            ("spices", "Spices", "Spices and food products", "restaurant"),
            ("gifts", "Gifts", "Souvenirs and gifts", "card_giftcard"),
            ("jewelry", "Jewelry", "Jewelry and accessories", "diamond"),
            ("home-decor", "Home decoration", "Moroccan home decor", "home"),
        ],
    },
    {
        "slug": "medina",
        "name": "Medina",
        "description": "Casablanca's old medina — dense commercial streets near the port and historic center.",
        "known_for": "Everyday goods, textiles, food, household items and local commerce.",
        "address": "Medina",
        "district": "Medina",
        "latitude": 33.6031,
        "longitude": -7.6167,
        "display_order": 5,
        "categories": [
            ("textiles", "Textiles", "Fabrics and textiles", "texture"),
            ("household", "Household goods", "Home and kitchen goods", "kitchen"),
            ("food", "Food products", "Local food and pantry items", "local_grocery_store"),
            ("clothing", "Clothing", "Everyday clothing", "checkroom"),
            ("hardware", "Hardware", "Tools and hardware", "hardware"),
            ("services", "Services", "Local services", "handyman"),
        ],
    },
    {
        "slug": "bab-marrakech",
        "name": "Bab Marrakech",
        "description": "Commercial district around Bab Marrakech — busy shopping streets in central Casablanca.",
        "known_for": "Mixed retail, clothing, electronics and everyday shopping.",
        "address": "Bab Marrakech",
        "district": "Bab Marrakech",
        "latitude": 33.5958,
        "longitude": -7.6169,
        "display_order": 6,
        "categories": [
            ("clothing", "Clothing", "Fashion and apparel", "checkroom"),
            ("electronics", "Electronics", "Electronics and accessories", "devices"),
            ("phones", "Phones", "Mobile phones", "smartphone"),
            ("shoes", "Shoes", "Footwear", "steps"),
            ("accessories", "Accessories", "Bags and accessories", "shopping_bag"),
            ("services", "Services", "Repairs and services", "build"),
        ],
    },
]

MARKET_UPDATES = [
    (
        "derb-ghallef",
        "Casablanca's major electronics and mobile phone market — hundreds of shops and galleries.",
        "Electronics, phones, computers, gaming, repairs, cameras and resale.",
    ),
    (
        "derb-omar",
        "Major wholesale and hardware commercial district in Casablanca.",
        "Wholesale textiles, clothing, household goods, hardware and packaging.",
    ),
    (
        "9ri3a",
        "Souk Al Qurayaa (القريعة) — auto parts, mechanics and car services.",
        "Auto parts, tires, mechanics and vehicle services.",
    ),
]


def upgrade() -> None:
    op.add_column(
        "marketplaces",
        sa.Column("known_for", sa.Text(), nullable=False, server_default=""),
    )
    op.add_column("seller_profiles", sa.Column("market_zone", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("seller_profiles", sa.Column("market_street", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("seller_profiles", sa.Column("market_gallery", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("seller_profiles", sa.Column("shop_number", sa.String(length=32), nullable=False, server_default=""))
    op.add_column("seller_profiles", sa.Column("market_floor", sa.String(length=64), nullable=False, server_default=""))
    op.add_column("seller_profiles", sa.Column("nearby_landmark", sa.String(length=255), nullable=False, server_default=""))

    for slug, description, known_for in MARKET_UPDATES:
        op.execute(
            sa.text(
                """
                UPDATE marketplaces
                SET description = :description, known_for = :known_for
                WHERE slug = :slug
                """
            ).bindparams(slug=slug, description=description, known_for=known_for)
        )

    # Expand Derb Ghallef categories for market-first discovery.
    op.execute(
        sa.text(
            """
            INSERT INTO marketplace_categories (id, marketplace_id, name, slug, description, icon, display_order, is_active)
            SELECT gen_random_uuid(), m.id, v.name, v.slug, v.description, v.icon, v.display_order, true
            FROM marketplaces m
            CROSS JOIN (VALUES
              ('accessories', 'Accessories', 'Phone and device accessories', 'headphones', 7),
              ('cameras', 'Cameras', 'Cameras and photography', 'photo_camera', 8),
              ('tv-audio', 'TV / Audio', 'Televisions and audio equipment', 'tv', 9),
              ('furniture', 'Furniture', 'Furniture and home items', 'chair', 10),
              ('clothing', 'Clothing', 'Clothing and apparel', 'checkroom', 11),
              ('other', 'Other', 'Other relevant categories', 'category', 99)
            ) AS v(slug, name, description, icon, display_order)
            WHERE m.slug = 'derb-ghallef'
            ON CONFLICT (marketplace_id, slug) DO UPDATE SET
              name = EXCLUDED.name,
              description = EXCLUDED.description,
              icon = EXCLUDED.icon,
              display_order = EXCLUDED.display_order
            """
        )
    )

    # Expand Derb Omar categories.
    op.execute(
        sa.text(
            """
            INSERT INTO marketplace_categories (id, marketplace_id, name, slug, description, icon, display_order, is_active)
            SELECT gen_random_uuid(), m.id, v.name, v.slug, v.description, v.icon, v.display_order, true
            FROM marketplaces m
            CROSS JOIN (VALUES
              ('wholesale', 'Wholesale', 'Wholesale goods', 'inventory_2', 5),
              ('textiles', 'Textiles', 'Fabrics and textiles', 'texture', 6),
              ('clothing', 'Clothing', 'Clothing wholesale', 'checkroom', 7),
              ('household', 'Household goods', 'Household products', 'home', 8),
              ('packaging', 'Packaging', 'Packaging supplies', 'inventory', 9),
              ('cosmetics', 'Cosmetics', 'Cosmetics and beauty', 'spa', 10),
              ('toys', 'Toys', 'Toys and games', 'toys', 11),
              ('electronics', 'Electronics', 'Electronics wholesale', 'devices', 12),
              ('other', 'Other', 'Other relevant categories', 'category', 99)
            ) AS v(slug, name, description, icon, display_order)
            WHERE m.slug = 'derb-omar'
            ON CONFLICT (marketplace_id, slug) DO UPDATE SET
              name = EXCLUDED.name,
              description = EXCLUDED.description,
              icon = EXCLUDED.icon,
              display_order = EXCLUDED.display_order
            """
        )
    )

    conn = op.get_bind()
    for market in NEW_MARKETS:
        market_id = str(uuid4())
        conn.execute(
            sa.text(
                """
                INSERT INTO marketplaces (
                    id, slug, name, description, known_for, address, district, city,
                    latitude, longitude, display_order, is_active
                ) VALUES (
                    :id, :slug, :name, :description, :known_for, :address, :district, 'Casablanca',
                    :latitude, :longitude, :display_order, true
                )
                ON CONFLICT (slug) DO UPDATE SET
                  name = EXCLUDED.name,
                  description = EXCLUDED.description,
                  known_for = EXCLUDED.known_for,
                  address = EXCLUDED.address,
                  district = EXCLUDED.district,
                  latitude = EXCLUDED.latitude,
                  longitude = EXCLUDED.longitude,
                  display_order = EXCLUDED.display_order
                """
            ),
            {
                "id": market_id,
                "slug": market["slug"],
                "name": market["name"],
                "description": market["description"],
                "known_for": market["known_for"],
                "address": market["address"],
                "district": market["district"],
                "latitude": market["latitude"],
                "longitude": market["longitude"],
                "display_order": market["display_order"],
            },
        )
        resolved_id = conn.execute(
            sa.text("SELECT id FROM marketplaces WHERE slug = :slug"),
            {"slug": market["slug"]},
        ).scalar_one()
        for order, (slug, name, description, icon) in enumerate(market["categories"], start=1):
            conn.execute(
                sa.text(
                    """
                    INSERT INTO marketplace_categories (
                        id, marketplace_id, name, slug, description, icon, display_order, is_active
                    ) VALUES (
                        :id, :marketplace_id, :name, :slug, :description, :icon, :display_order, true
                    )
                    ON CONFLICT (marketplace_id, slug) DO UPDATE SET
                      name = EXCLUDED.name,
                      description = EXCLUDED.description,
                      icon = EXCLUDED.icon,
                      display_order = EXCLUDED.display_order
                    """
                ),
                {
                    "id": str(uuid4()),
                    "marketplace_id": str(resolved_id),
                    "name": name,
                    "slug": slug,
                    "description": description,
                    "icon": icon,
                    "display_order": order,
                },
            )


def downgrade() -> None:
    for market in NEW_MARKETS:
        op.execute(sa.text("DELETE FROM marketplaces WHERE slug = :slug").bindparams(slug=market["slug"]))
    op.drop_column("seller_profiles", "nearby_landmark")
    op.drop_column("seller_profiles", "market_floor")
    op.drop_column("seller_profiles", "shop_number")
    op.drop_column("seller_profiles", "market_gallery")
    op.drop_column("seller_profiles", "market_street")
    op.drop_column("seller_profiles", "market_zone")
    op.drop_column("marketplaces", "known_for")
