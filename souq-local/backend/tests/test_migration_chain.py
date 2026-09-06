"""Regression: Alembic migration chain must upgrade cleanly on a fresh database."""

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


def test_alembic_upgrade_head_on_fresh_database():
    base_url = os.environ.get("DATABASE_URL")
    if not base_url:
        pytest.skip("DATABASE_URL not set")

    if "+asyncpg" not in base_url:
        pytest.skip("migration test requires asyncpg DATABASE_URL")

    sync_url = base_url.replace("+asyncpg", "")
    db_name = f"margem_migration_test_{uuid.uuid4().hex[:10]}"
    admin_url = sync_url.rsplit("/", 1)[0] + "/postgres"

    create_db = _run(
        ["psql", admin_url, "-c", f"CREATE DATABASE {db_name} OWNER souq;"],
        cwd=Path(__file__).resolve().parents[1],
        env=os.environ.copy(),
    )
    if create_db.returncode != 0:
        pytest.skip(f"cannot create migration test database: {create_db.stderr}")

    backend_root = Path(__file__).resolve().parents[1]
    test_db_url = base_url.rsplit("/", 1)[0] + f"/{db_name}"
    env = os.environ.copy()
    env["DATABASE_URL"] = test_db_url
    env.setdefault(
        "JWT_SECRET_KEY",
        "test-jwt-secret-key-minimum-32-characters-long",
    )

    try:
        heads = _run(["alembic", "heads"], cwd=backend_root, env=env)
        assert heads.returncode == 0, heads.stderr
        assert "018 is present more than once" not in heads.stderr
        head_lines = [
            line.strip()
            for line in heads.stdout.splitlines()
            if line.strip().endswith("(head)")
        ]
        assert len(head_lines) == 1, f"expected single head, got: {heads.stdout}"

        upgrade = _run(["alembic", "upgrade", "head"], cwd=backend_root, env=env)
        assert upgrade.returncode == 0, upgrade.stderr or upgrade.stdout
    finally:
        _run(
            ["psql", admin_url, "-c", f"DROP DATABASE IF EXISTS {db_name};"],
            cwd=backend_root,
            env=os.environ.copy(),
        )
