#!/usr/bin/env bash
# Restore a Dribex home-server database and its matching local media archive.
# Usage: ./scripts/restore_home_backup.sh backups/margem-YYYY.sql.gz
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_BACKUP="${1:?Usage: $0 path/to/margem-YYYY.sql.gz}"
DB_BACKUP="$(realpath "$DB_BACKUP")"

if [[ ! -f "$DB_BACKUP" ]]; then
  echo "Database backup not found: $DB_BACKUP" >&2
  exit 1
fi
if ! docker ps --format '{{.Names}}' | grep -qx 'margem-home-db'; then
  echo "Container margem-home-db is not running." >&2
  exit 1
fi

STAMP="$(basename "$DB_BACKUP" | sed -E 's/^margem-([0-9TZ]+)\.sql\.gz$/\1/')"
MEDIA_BACKUP="$(dirname "$DB_BACKUP")/margem-media-$STAMP.tar.gz"

read -r -p "This replaces the current Dribex database. Type RESTORE to continue: " confirm
[[ "$confirm" == "RESTORE" ]] || { echo "Cancelled."; exit 1; }

echo "Stopping API connections..."
docker compose -f "$ROOT/docker-compose.home.yml" stop api 2>/dev/null || true

echo "Recreating empty database..."
docker exec -i margem-home-db psql -v ON_ERROR_STOP=1 -U margemadmin -d postgres <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'margem' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS margem;
CREATE DATABASE margem OWNER margemadmin;
SQL

echo "Restoring database from backup..."
gunzip -c "$DB_BACKUP" | docker exec -i margem-home-db psql -v ON_ERROR_STOP=1 -U margemadmin -d margem

if [[ -f "$MEDIA_BACKUP" ]]; then
  echo "Restoring local media..."
  docker run --rm \
    -v margem_home_media:/target \
    -v "$(dirname "$MEDIA_BACKUP")":/backup:ro \
    alpine:3.20 \
    sh -c "rm -rf /target/* && tar -C /target -xzf /backup/$(basename "$MEDIA_BACKUP")"
else
  echo "No matching media archive found: $MEDIA_BACKUP" >&2
  echo "Database restored, but listing images were not restored." >&2
fi

echo "Restore completed. Restarting services..."
cd "$ROOT"
docker compose -f docker-compose.home.yml --env-file .env.home up -d
