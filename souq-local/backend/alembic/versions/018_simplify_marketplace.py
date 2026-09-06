"""Simplify marketplace: customer/provider roles, pricing_type, 12 categories, Casablanca-only data.

Revision ID: 018
Revises: 017
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "018"
down_revision: Union[str, None] = "017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE accounttype RENAME VALUE 'buyer' TO 'customer'")
    op.execute("ALTER TYPE accounttype RENAME VALUE 'seller' TO 'provider'")
    op.execute("ALTER TYPE userrole RENAME VALUE 'buyer' TO 'customer'")
    op.execute("ALTER TYPE userrole RENAME VALUE 'seller' TO 'provider'")

    pricing_type = sa.Enum("fixed", "offer", name="pricingtype")
    pricing_type.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "products",
        sa.Column("pricing_type", pricing_type, nullable=False, server_default="fixed"),
    )
    op.add_column(
        "products",
        sa.Column("delivery_available", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        "products",
        sa.Column("pickup_only", sa.Boolean(), nullable=False, server_default=sa.true()),
    )
    op.add_column(
        "services",
        sa.Column("pricing_type", pricing_type, nullable=False, server_default="fixed"),
    )
    op.add_column(
        "services",
        sa.Column("category_slug", sa.String(length=80), nullable=False, server_default=""),
    )

    op.execute(
        """
        UPDATE products
        SET pricing_type = 'offer'
        WHERE price_negotiable = TRUE OR price_mad IS NULL
        """
    )
    op.execute(
        """
        UPDATE services
        SET pricing_type = 'offer'
        WHERE price_negotiable = TRUE
           OR price_mad IS NULL
           OR pricing_model IN ('negotiable', 'request_quote')
        """
    )

    op.execute(
        """
        UPDATE products
        SET delivery_available = TRUE,
            pickup_only = FALSE
        WHERE delivery_options::text ILIKE '%delivery%'
           OR delivery_options::text ILIKE '%local_delivery%'
        """
    )

    op.execute(
        """
        UPDATE seller_profiles
        SET city = 'Casablanca'
        WHERE city IS NULL OR city = '' OR city <> 'Casablanca'
        """
    )

    op.execute("DELETE FROM seller_categories")
    op.execute("DELETE FROM categories")

    categories = [
        ("clothing", "Clothes", "Vêtements", "ملابس", "checkroom"),
        ("shoes", "Shoes", "Chaussures", "أحذية", "steps"),
        ("perfumes", "Perfumes", "Parfums", "عطور", "fragrance"),
        ("beauty", "Beauty", "Beauté", "جمال", "spa"),
        ("electronics", "Electronics", "Électronique", "إلكترونيات", "devices"),
        ("food", "Food", "Nourriture", "طعام", "restaurant"),
        ("home", "Home", "Maison", "منزل", "home"),
        ("jewelry", "Jewelry", "Bijoux", "مجوهرات", "diamond"),
        ("accessories", "Accessories", "Accessoires", "إكسسوارات", "watch"),
        ("sports", "Sports", "Sport", "رياضة", "sports_soccer"),
        ("health", "Health", "Santé", "صحة", "local_hospital"),
        ("kids", "Kids", "Enfants", "أطفال", "child_care"),
    ]
    bind = op.get_bind()
    for slug, en, fr, ar, icon in categories:
        bind.execute(
            sa.text(
                """
                INSERT INTO categories (id, slug, name_en, name_fr, name_ar, icon)
                VALUES (gen_random_uuid(), :slug, :en, :fr, :ar, :icon)
                """
            ),
            {"slug": slug, "en": en, "fr": fr, "ar": ar, "icon": icon},
        )

    op.execute(
        """
        UPDATE products SET category_slug = 'home'
        WHERE category_slug IN ('services', 'home-garden')
        """
    )
    op.execute(
        """
        UPDATE products SET category_slug = 'electronics'
        WHERE category_slug IN ('phones', 'laptops', 'gaming', 'electronics-gadgets')
        """
    )
    op.execute(
        """
        UPDATE products SET category_slug = 'home'
        WHERE category_slug IN ('furniture', 'decor', 'appliances', 'collectibles')
        """
    )
    op.execute(
        """
        UPDATE products SET category_slug = 'clothing'
        WHERE category_slug IN ('fashion', 'menswear', 'womenswear')
        """
    )
    op.execute(
        """
        UPDATE products SET category_slug = ''
        WHERE category_slug <> ''
          AND category_slug NOT IN (
            'clothing','shoes','perfumes','beauty','electronics','food',
            'home','jewelry','accessories','sports','health','kids'
          )
        """
    )


def downgrade() -> None:
    op.drop_column("services", "category_slug")
    op.drop_column("services", "pricing_type")
    op.drop_column("products", "pickup_only")
    op.drop_column("products", "delivery_available")
    op.drop_column("products", "pricing_type")
    op.execute("DROP TYPE IF EXISTS pricingtype")

    op.execute("ALTER TYPE accounttype RENAME VALUE 'customer' TO 'buyer'")
    op.execute("ALTER TYPE accounttype RENAME VALUE 'provider' TO 'seller'")
    op.execute("ALTER TYPE userrole RENAME VALUE 'customer' TO 'buyer'")
    op.execute("ALTER TYPE userrole RENAME VALUE 'provider' TO 'seller'")
