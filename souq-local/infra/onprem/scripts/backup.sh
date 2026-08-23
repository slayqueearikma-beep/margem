#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.prod}"
COMPOSE="docker compose -f $ROOT/docker-compose.prod.yml --env-file $ENV_FILE"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/margem}"
STAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP_DIR"

source "$ENV_FILE"

echo "[1/3] PostgreSQL dump"
$COMPOSE exec -T postgres pg_dump -U "${POSTGRES_USER:-margem}" -d "${POSTGRES_DB:-margem}" \
  | gzip > "$BACKUP_DIR/postgres-$STAMP.sql.gz"

echo "[2/3] MinIO bucket sync"
$COMPOSE run --rm --entrypoint sh minio -c \
  "mc alias set local http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc mirror local/${MINIO_BUCKET:-margem-media} /backup" \
  -v "$BACKUP_DIR/minio-$STAMP:/backup" 2>/dev/null || \
  echo "MinIO mirror skipped (install mc in minio image or run mc from host)"

echo "[3/3] Retention — keep last 14 daily backups"
ls -1t "$BACKUP_DIR"/postgres-*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f

echo "Backup complete: $BACKUP_DIR/postgres-$STAMP.sql.gz"
