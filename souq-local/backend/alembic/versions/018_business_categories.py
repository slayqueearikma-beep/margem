"""Business category taxonomy: accent colors + 54 categories.

Revision ID: 018
Revises: 017
"""

from __future__ import annotations

from uuid import uuid4

import sqlalchemy as sa
from alembic import op

from app.data.business_categories import BUSINESS_CATEGORIES, LEGACY_CATEGORY_SLUGS

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "categories",
        sa.Column("accent_color", sa.String(length=7), server_default="#5B6CFF", nullable=False),
    )

    bind = op.get_bind()
    for index, legacy_slug in enumerate(LEGACY_CATEGORY_SLUGS, start=900):
        bind.execute(
            sa.text("UPDATE categories SET sort_order = :sort_order WHERE slug = :slug"),
            {"sort_order": index, "slug": legacy_slug},
        )

    for cat in BUSINESS_CATEGORIES:
        bind.execute(
            sa.text(
                """
                INSERT INTO categories (
                    id, slug, name_en, name_fr, name_ar, icon, sort_order, accent_color
                ) VALUES (
                    :id, :slug, :name_en, :name_fr, :name_ar, :icon, :sort_order, :accent_color
                )
                ON CONFLICT (slug) DO UPDATE SET
                    name_en = EXCLUDED.name_en,
                    name_fr = EXCLUDED.name_fr,
                    name_ar = EXCLUDED.name_ar,
                    icon = EXCLUDED.icon,
                    sort_order = EXCLUDED.sort_order,
                    accent_color = EXCLUDED.accent_color
                """
            ),
            {
                "id": uuid4(),
                "slug": cat.slug,
                "name_en": cat.name_en,
                "name_fr": cat.name_fr,
                "name_ar": cat.name_ar,
                "icon": cat.icon,
                "sort_order": cat.sort_order,
                "accent_color": cat.accent_color,
            },
        )


def downgrade() -> None:
    bind = op.get_bind()
    for cat in BUSINESS_CATEGORIES:
        bind.execute(sa.text("DELETE FROM categories WHERE slug = :slug"), {"slug": cat.slug})
    for index, legacy_slug in enumerate(LEGACY_CATEGORY_SLUGS):
        bind.execute(
            sa.text("UPDATE categories SET sort_order = :sort_order WHERE slug = :slug"),
            {"sort_order": index, "slug": legacy_slug},
        )
    op.drop_column("categories", "accent_color")
