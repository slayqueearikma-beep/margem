#!/usr/bin/env bash
# Production deployment — canonical on-prem path.
# Run on the server after validating .env.prod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ONPREM="$ROOT/infra/onprem"
ENV_FILE="${ENV_FILE:-$ONPREM/.env.prod}"
COMPOSE_FILE="${COMPOSE_FILE:-$ONPREM/docker-compose.prod.yml}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy from infra/onprem/env.prod.example" >&2
  exit 1
fi

export ENV_FILE

echo "==> Validate production environment"
chmod +x "$ONPREM/scripts/validate-production-env.sh"
"$ONPREM/scripts/validate-production-env.sh" "$ENV_FILE"

echo "==> Backup database and media"
"$ONPREM/scripts/backup.sh" || true

echo "==> Build images"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build api web

echo "==> Start data services"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d postgres minio redis
sleep 5

echo "==> Run migrations"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" run --rm api alembic upgrade head

echo "==> Deploy full production stack"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d

echo "==> Health check"
API_URL="$(grep -E '^PUBLIC_API_URL=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")"
curl -fsS "${API_URL}/ready" | head -c 200
echo ""
echo "Deployment complete. Verify public access: $ONPREM/scripts/verify-public-api.sh"
