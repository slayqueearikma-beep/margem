"""Regression: repair migration 032 restores geography when 018b was skipped."""

from __future__ import annotations

import os
import subprocess
import uuid
from pathlib import Path

import pytest


def _run(cmd: list[str], *, cwd: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


def test_repair_migration_restores_skipped_geography():
    base_url = os.environ.get("DATABASE_URL")
    if not base_url:
        pytest.skip("DATABASE_URL not set")

    if "+asyncpg" not in base_url:
        pytest.skip("migration test requires asyncpg DATABASE_URL")

    sync_url = base_url.replace("+asyncpg", "")
    db_name = f"margem_geo_repair_{uuid.uuid4().hex[:10]}"
    admin_url = sync_url.rsplit("/", 1)[0] + "/postgres"
    test_db_url = sync_url.rsplit("/", 1)[0] + f"/{db_name}"

    create_db = _run(
        ["psql", admin_url, "-c", f"CREATE DATABASE {db_name} OWNER souq;"],
        cwd=Path(__file__).resolve().parents[1],
        env=os.environ.copy(),
    )
    if create_db.returncode != 0:
        pytest.skip(f"cannot create migration test database: {create_db.stderr}")

    backend_root = Path(__file__).resolve().parents[1]
    env = os.environ.copy()
    env["DATABASE_URL"] = base_url.rsplit("/", 1)[0] + f"/{db_name}"
    env.setdefault(
        "JWT_SECRET_KEY",
        "test-jwt-secret-key-minimum-32-characters-long",
    )

    drop_geography_sql = """
    ALTER TABLE cities DROP CONSTRAINT IF EXISTS fk_cities_country_id_countries;
    DROP INDEX IF EXISTS ix_cities_country_id;
    DROP INDEX IF EXISTS ix_cities_name_en;
    DROP INDEX IF EXISTS ix_cities_sort_order;
    ALTER TABLE cities DROP COLUMN IF EXISTS country_id;
    ALTER TABLE cities DROP COLUMN IF EXISTS name_en;
    ALTER TABLE cities DROP COLUMN IF EXISTS name_ar;
    ALTER TABLE cities DROP COLUMN IF EXISTS name_fr;
    ALTER TABLE cities DROP COLUMN IF EXISTS region;
    ALTER TABLE cities DROP COLUMN IF EXISTS latitude;
    ALTER TABLE cities DROP COLUMN IF EXISTS longitude;
    ALTER TABLE cities DROP COLUMN IF EXISTS sort_order;
    DROP TABLE IF EXISTS countries CASCADE;
    """

    try:
        upgrade_031 = _run(["alembic", "upgrade", "031"], cwd=backend_root, env=env)
        assert upgrade_031.returncode == 0, upgrade_031.stderr or upgrade_031.stdout

        drop_geo = _run(["psql", test_db_url, "-c", drop_geography_sql], cwd=backend_root, env=env)
        assert drop_geo.returncode == 0, drop_geo.stderr or drop_geo.stdout

        upgrade_head = _run(["alembic", "upgrade", "head"], cwd=backend_root, env=env)
        assert upgrade_head.returncode == 0, upgrade_head.stderr or upgrade_head.stdout

        verify = _run(
            [
                "psql",
                test_db_url,
                "-tAc",
                "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'countries') "
                "AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'cities' "
                "AND column_name = 'country_id') "
                "AND EXISTS (SELECT 1 FROM countries WHERE code = 'MA') "
                "AND (SELECT COUNT(*) FROM cities) >= 20;",
            ],
            cwd=backend_root,
            env=env,
        )
        assert verify.returncode == 0, verify.stderr or verify.stdout
        assert verify.stdout.strip() == "t", verify.stdout
    finally:
        _run(
            ["psql", admin_url, "-c", f"DROP DATABASE IF EXISTS {db_name};"],
            cwd=backend_root,
            env=os.environ.copy(),
        )
