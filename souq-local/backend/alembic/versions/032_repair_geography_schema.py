"""Repair geography schema when migration 018b was skipped on existing databases.

Some deployments migrated from 018 -> 019 before 018b was inserted into the chain.
Alembic then treats 018b as already applied even though countries/city columns were
never created. This idempotent repair recreates any missing pieces.
"""

from __future__ import annotations

import uuid

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "032"
down_revision = "031"
branch_labels = None
depends_on = None

MOROCCO_ID = uuid.UUID("00000000-0000-4000-8000-000000000001")

CITIES = [
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


def _table_exists(inspector: sa.Inspector, name: str) -> bool:
    return name in inspector.get_table_names()


def _column_exists(inspector: sa.Inspector, table: str, column: str) -> bool:
    return any(col["name"] == column for col in inspector.get_columns(table))


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not _table_exists(inspector, "countries"):
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

    inspector = sa.inspect(bind)
    city_columns = {
        "country_id": sa.Column("country_id", sa.UUID(), nullable=True),
        "name_en": sa.Column("name_en", sa.String(length=120), nullable=False, server_default=""),
        "name_ar": sa.Column("name_ar", sa.String(length=120), nullable=False, server_default=""),
        "name_fr": sa.Column("name_fr", sa.String(length=120), nullable=False, server_default=""),
        "region": sa.Column("region", sa.String(length=120), nullable=False, server_default=""),
        "latitude": sa.Column("latitude", sa.Float(), nullable=False, server_default="0"),
        "longitude": sa.Column("longitude", sa.Float(), nullable=False, server_default="0"),
        "sort_order": sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
    }
    for column_name, column in city_columns.items():
        if not _column_exists(inspector, "cities", column_name):
            op.add_column("cities", column)

    inspector = sa.inspect(bind)
    fk_names = {fk["name"] for fk in inspector.get_foreign_keys("cities")}
    if "fk_cities_country_id_countries" not in fk_names and _table_exists(inspector, "countries"):
        op.create_foreign_key(
            "fk_cities_country_id_countries",
            "cities",
            "countries",
            ["country_id"],
            ["id"],
            ondelete="SET NULL",
        )

    index_names = {idx["name"] for idx in inspector.get_indexes("cities")}
    if "ix_cities_country_id" not in index_names:
        op.create_index("ix_cities_country_id", "cities", ["country_id"])
    if "ix_cities_name_en" not in index_names:
        op.create_index("ix_cities_name_en", "cities", ["name_en"])
    if "ix_cities_sort_order" not in index_names:
        op.create_index("ix_cities_sort_order", "cities", ["sort_order"])

    conn = op.get_bind()
    existing_country = conn.execute(
        sa.text("SELECT id FROM countries WHERE code = 'MA'"),
    ).fetchone()
    if existing_country is None:
        conn.execute(
            sa.text(
                """
                INSERT INTO countries (id, code, name_en, name_ar, name_fr, is_active)
                VALUES (:id, 'MA', 'Morocco', 'المغرب', 'Maroc', true)
                """
            ),
            {"id": str(MOROCCO_ID)},
        )

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
                    "description": f"Dribex community for {name_en}",
                },
            )

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
    # Repair migration — no downgrade; geography schema is required.
    pass
