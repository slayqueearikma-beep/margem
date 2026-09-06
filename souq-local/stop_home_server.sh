#!/usr/bin/env bash
# Stop Dribex home server containers (local media and DB volumes persist).
# Usage: ./stop_home_server.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT/.env.home"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"

echo ""
echo "Stopping home server containers..."

if [[ -f "$ENV_FILE" ]]; then
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
else
  docker compose -f "$COMPOSE_FILE" down
fi

echo "Stopped. Database and media volumes are preserved on this machine."
echo ""
