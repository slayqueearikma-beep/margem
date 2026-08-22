#!/usr/bin/env bash
# Production deployment helper — run on the server after CI passes staging tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.production}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/infra/onprem/docker-compose.prod.yml}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy from env.production.example"
  exit 1
fi

echo "==> Backup database"
"$ROOT/infra/onprem/scripts/backup.sh" || true

echo "==> Pull latest images / build"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build api

echo "==> Run migrations (via entrypoint)"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d postgres minio redis
sleep 5
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" run --rm api alembic upgrade head

echo "==> Deploy API + nginx"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d api nginx

echo "==> Health check"
curl -fsS "$(grep PUBLIC_API_URL "$ENV_FILE" | cut -d= -f2)/ready" | head -c 200
echo ""
echo "Deployment complete."
