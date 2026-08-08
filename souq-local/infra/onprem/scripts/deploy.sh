#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.prod}"
COMPOSE="docker compose -f $ROOT/docker-compose.prod.yml --env-file $ENV_FILE"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy env.prod.example first." >&2
  exit 1
fi

mkdir -p "$ROOT/nginx/certs"
if [[ ! -f "$ROOT/nginx/certs/fullchain.pem" ]]; then
  echo "Generating self-signed TLS cert for bootstrap (replace with Let's Encrypt in production)."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$ROOT/nginx/certs/privkey.pem" \
    -out "$ROOT/nginx/certs/fullchain.pem" \
    -subj "/CN=localhost"
fi

$COMPOSE build api
$COMPOSE up -d
$COMPOSE ps

echo "Waiting for API readiness..."
for i in $(seq 1 30); do
  if $COMPOSE exec -T api python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/ready')" 2>/dev/null; then
    echo "API ready."
    exit 0
  fi
  sleep 2
done
echo "API not ready — check logs: $COMPOSE logs api" >&2
exit 1
