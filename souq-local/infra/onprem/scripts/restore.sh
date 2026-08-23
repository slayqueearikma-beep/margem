#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/postgres-YYYYMMDD-HHMMSS.sql.gz" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.prod}"
COMPOSE="docker compose -f $ROOT/docker-compose.prod.yml --env-file $ENV_FILE"
DUMP="$1"

source "$ENV_FILE"

echo "Restoring $DUMP into ${POSTGRES_DB:-margem}"
gunzip -c "$DUMP" | $COMPOSE exec -T postgres psql -U "${POSTGRES_USER:-margem}" -d "${POSTGRES_DB:-margem}"
echo "Restore complete. Restart API: $COMPOSE restart api"
