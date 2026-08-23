"""Extend cities with Morocco geography data and seed 20 cities."""

from __future__ import annotations

import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None

MOROCCO_ID = uuid.UUID("00000000-0000-4000-8000-000000000001")

CITIES = [
    # slug, name_en, name_fr, name_ar, region, lat, lng, sort_order
    ("casablanca", "Casablanca", "Casablanca", "الدار البيضاء", "Casablanca-Settat", 33.5731, -7.5898, 1),
    ("rabat", "Rabat", "Rabat", "الرباط", "Rabat-Salé-Kénitra", 34.0209, -6.8416, 2),
    ("marrakech", "Marrakech", "Marrakech", "مراكش", "Marrakech-Safi", 31.6295, -7.9811, 3),
    ("fes", "Fes", "Fès", "فاس", "Fès-Meknès", 34.0331, -5.0003, 4),
    ("tangier", "Tangier", "Tanger", "طنجة", "Tangier-Tetouan-Al Hoceima", 35.7595, -5.8340, 5),
    ("agadir", "Agadir", "Agadir", "أكادير", "Souss-Massa", 30.4278, -9.5981, 6),
    ("meknes", "Meknes", "Meknès", "مكناس", "Fès-Meknès", 33.8935, -5.5473, 7),
    ("oujda", "Oujda", "Oujda", "وجدة", "Oriental", 34.6814, -1.9086, 8),
    ("kenitra", "Kenitra", "Kénitra", "القنيطرة", "Rabat-Salé-Kénitra", 34.2610, -6.5802, 9),
    ("tetouan", "Tetouan", "Tétouan", "تطوان", "Tangier-Tetouan-Al Hoceima", 35.5889, -5.3626, 10),
    ("sale", "Sale", "Salé", "سلا", "Rabat-Salé-Kénitra", 34.0531, -6.7985, 11),
    ("nador", "Nador", "Nador", "الناظور", "Oriental", 35.1688, -2.9286, 12),
    ("mohammedia", "Mohammedia", "Mohammedia", "المحمدية", "Casablanca-Settat", 33.6866, -7.3830, 13),
    ("el-jadida", "El Jadida", "El Jadida", "الجديدة", "Casablanca-Settat", 33.2316, -8.5007, 14),
    ("beni-mellal", "Beni Mellal", "Béni Mellal", "بني ملال", "Béni Mellal-Khénifra", 32.3373, -6.3498, 15),
    ("khouribga", "Khouribga", "Khouribga", "خريبكة", "Béni Mellal-Khénifra", 32.8867, -6.9209, 16),
    ("taza", "Taza", "Taza", "تازة", "Fès-Meknès", 34.2139, -4.0086, 17),
    ("settat", "Settat", "Settat", "سطات", "Casablanca-Settat", 33.0019, -7.6169, 18),
    ("larache", "Larache", "Larache", "العرائش", "Tangier-Tetouan-Al Hoceima", 35.1874, -6.1557, 19),
    ("safi", "Safi", "Safi", "آسفي", "Marrakech-Safi", 32.2994, -9.2372, 20),
]


def upgrade() -> None:
    op.create_table(
        "countries",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("code", sa.String(length=2), nullable=False),
        sa.Column("name_en", sa.String(length=120), nullable=False),
        sa.Column("name_ar", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("name_fr", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_countries_code", "countries", ["code"], unique=True)
    op.create_index("ix_countries_is_active", "countries", ["is_active"])

    op.add_column("cities", sa.Column("country_id", sa.UUID(), nullable=True))
    op.add_column("cities", sa.Column("name_en", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("cities", sa.Column("name_ar", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("cities", sa.Column("name_fr", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("cities", sa.Column("region", sa.String(length=120), nullable=False, server_default=""))
    op.add_column("cities", sa.Column("latitude", sa.Float(), nullable=False, server_default="0"))
    op.add_column("cities", sa.Column("longitude", sa.Float(), nullable=False, server_default="0"))
    op.add_column("cities", sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"))
    op.create_foreign_key(
        "fk_cities_country_id_countries",
        "cities",
        "countries",
        ["country_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_cities_country_id", "cities", ["country_id"])
    op.create_index("ix_cities_name_en", "cities", ["name_en"])
    op.create_index("ix_cities_sort_order", "cities", ["sort_order"])

    countries = sa.table(
        "countries",
        sa.column("id", postgresql.UUID()),
        sa.column("code", sa.String),
        sa.column("name_en", sa.String),
        sa.column("name_ar", sa.String),
        sa.column("name_fr", sa.String),
        sa.column("is_active", sa.Boolean),
    )
    op.bulk_insert(
        countries,
        [
            {
                "id": str(MOROCCO_ID),
                "code": "MA",
                "name_en": "Morocco",
                "name_ar": "المغرب",
                "name_fr": "Maroc",
                "is_active": True,
            }
        ],
    )

    conn = op.get_bind()
    for slug, name_en, name_fr, name_ar, region, lat, lng, sort_order in CITIES:
        existing = conn.execute(
            sa.text("SELECT id FROM cities WHERE slug = :slug"),
            {"slug": slug},
        ).fetchone()
        if existing:
            conn.execute(
                sa.text(
                    """
                    UPDATE cities SET
                        country_id = :country_id,
                        name = :name_en,
                        name_en = :name_en,
                        name_fr = :name_fr,
                        name_ar = :name_ar,
                        region = :region,
                        latitude = :lat,
                        longitude = :lng,
                        sort_order = :sort_order,
                        is_active = true
                    WHERE slug = :slug
                    """
                ),
                {
                    "country_id": str(MOROCCO_ID),
                    "name_en": name_en,
                    "name_fr": name_fr,
                    "name_ar": name_ar,
                    "region": region,
                    "lat": lat,
                    "lng": lng,
                    "sort_order": sort_order,
                    "slug": slug,
                },
            )
        else:
            conn.execute(
                sa.text(
                    """
                    INSERT INTO cities (
                        id, country_id, slug, name, name_en, name_fr, name_ar,
                        region, latitude, longitude, sort_order, description,
                        is_active, member_count, message_count
                    ) VALUES (
                        :id, :country_id, :slug, :name_en, :name_en, :name_fr, :name_ar,
                        :region, :lat, :lng, :sort_order, :description,
                        true, 0, 0
                    )
                    """
                ),
                {
                    "id": str(uuid.uuid4()),
                    "country_id": str(MOROCCO_ID),
                    "slug": slug,
                    "name_en": name_en,
                    "name_fr": name_fr,
                    "name_ar": name_ar,
                    "region": region,
                    "lat": lat,
                    "lng": lng,
                    "sort_order": sort_order,
                    "description": f"MarGem community for {name_en}",
                },
            )

    # Backfill any legacy rows missing geography labels.
    conn.execute(
        sa.text(
            """
            UPDATE cities
            SET name_en = name
            WHERE name_en = '' AND name <> ''
            """
        )
    )


def downgrade() -> None:
    op.drop_index("ix_cities_sort_order", table_name="cities")
    op.drop_index("ix_cities_name_en", table_name="cities")
    op.drop_constraint("fk_cities_country_id_countries", "cities", type_="foreignkey")
    op.drop_index("ix_cities_country_id", table_name="cities")
    op.drop_column("cities", "sort_order")
    op.drop_column("cities", "longitude")
    op.drop_column("cities", "latitude")
    op.drop_column("cities", "region")
    op.drop_column("cities", "name_fr")
    op.drop_column("cities", "name_ar")
    op.drop_column("cities", "name_en")
    op.drop_column("cities", "country_id")
    op.drop_index("ix_countries_is_active", table_name="countries")
    op.drop_index("ix_countries_code", table_name="countries")
    op.drop_table("countries")
