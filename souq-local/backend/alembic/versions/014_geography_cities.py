"""Geography: countries + Moroccan cities seed."""

from __future__ import annotations

import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "014"
down_revision = "013"
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

    op.create_table(
        "cities",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("country_id", sa.UUID(), nullable=False),
        sa.Column("slug", sa.String(length=80), nullable=False),
        sa.Column("name_en", sa.String(length=120), nullable=False),
        sa.Column("name_ar", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("name_fr", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("region", sa.String(length=120), nullable=False, server_default=""),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["country_id"], ["countries.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cities_slug", "cities", ["slug"], unique=True)
    op.create_index("ix_cities_country_id", "cities", ["country_id"])
    op.create_index("ix_cities_is_active", "cities", ["is_active"])
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

    cities = sa.table(
        "cities",
        sa.column("id", postgresql.UUID()),
        sa.column("country_id", postgresql.UUID()),
        sa.column("slug", sa.String),
        sa.column("name_en", sa.String),
        sa.column("name_ar", sa.String),
        sa.column("name_fr", sa.String),
        sa.column("region", sa.String),
        sa.column("latitude", sa.Float),
        sa.column("longitude", sa.Float),
        sa.column("is_active", sa.Boolean),
        sa.column("sort_order", sa.Integer),
    )
    op.bulk_insert(
        cities,
        [
            {
                "id": str(uuid.uuid4()),
                "country_id": str(MOROCCO_ID),
                "slug": slug,
                "name_en": name_en,
                "name_fr": name_fr,
                "name_ar": name_ar,
                "region": region,
                "latitude": lat,
                "longitude": lng,
                "is_active": True,
                "sort_order": sort_order,
            }
            for slug, name_en, name_fr, name_ar, region, lat, lng, sort_order in CITIES
        ],
    )


def downgrade() -> None:
    op.drop_index("ix_cities_sort_order", table_name="cities")
    op.drop_index("ix_cities_name_en", table_name="cities")
    op.drop_index("ix_cities_is_active", table_name="cities")
    op.drop_index("ix_cities_country_id", table_name="cities")
    op.drop_index("ix_cities_slug", table_name="cities")
    op.drop_table("cities")
    op.drop_index("ix_countries_is_active", table_name="countries")
    op.drop_index("ix_countries_code", table_name="countries")
    op.drop_table("countries")
