#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.prod}"
COMPOSE="docker compose -f $ROOT/docker-compose.prod.yml --env-file $ENV_FILE"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/margem}"
STAMP="$(date +%Y%m%d-%H%M%S)"
MC_IMAGE="${MC_IMAGE:-minio/mc:RELEASE.2025-01-17T23-25-50Z}"

mkdir -p "$BACKUP_DIR"

# shellcheck disable=SC1090
source "$ENV_FILE"

BUCKETS=(
  "${MINIO_BUCKET:-margem-media}"
  "${MINIO_BUCKET_PROFILES:-dribex-profiles}"
  "${MINIO_BUCKET_PRODUCTS:-dribex-products}"
  "${MINIO_BUCKET_LISTINGS:-dribex-listings}"
  "${MINIO_BUCKET_PRIVATE:-dribex-private}"
)

echo "[1/4] PostgreSQL dump"
$COMPOSE exec -T postgres pg_dump -U "${POSTGRES_USER:-margem}" -d "${POSTGRES_DB:-margem}" \
  | gzip > "$BACKUP_DIR/postgres-$STAMP.sql.gz"

echo "[2/4] MinIO bucket sync (all application buckets)"
MINIO_NET="$($COMPOSE ps -q minio | xargs -r docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' | head -1)"
if [[ -z "$MINIO_NET" ]]; then
  echo "ERROR: cannot resolve Docker network for MinIO — is the stack running?" >&2
  exit 1
fi

MINIO_BACKUP_ROOT="$BACKUP_DIR/minio-$STAMP"
mkdir -p "$MINIO_BACKUP_ROOT"

for bucket in "${BUCKETS[@]}"; do
  echo "  -> mirroring bucket: $bucket"
  docker run --rm \
    --network "$MINIO_NET" \
    -v "$MINIO_BACKUP_ROOT:/backup" \
    -e "MC_HOST_local=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000" \
    "$MC_IMAGE" \
    mirror "local/${bucket}" "/backup/${bucket}"
done

echo "[3/4] Retention — keep last 14 daily backups"
ls -1t "$BACKUP_DIR"/postgres-*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f
ls -1dt "$BACKUP_DIR"/minio-* 2>/dev/null | tail -n +15 | xargs -r rm -rf

echo "[4/4] Backup manifest"
cat > "$BACKUP_DIR/manifest-$STAMP.txt" <<EOF
timestamp=$STAMP
postgres=$BACKUP_DIR/postgres-$STAMP.sql.gz
minio=$MINIO_BACKUP_ROOT
buckets=${BUCKETS[*]}
EOF

echo "Backup complete:"
echo "  Postgres: $BACKUP_DIR/postgres-$STAMP.sql.gz"
echo "  MinIO:    $MINIO_BACKUP_ROOT"
