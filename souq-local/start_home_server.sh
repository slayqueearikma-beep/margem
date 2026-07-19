#!/usr/bin/env bash
# Start MarGem home server (API + Postgres) and optionally Flutter on a connected phone.
# Usage:
#   ./start_home_server.sh              # Docker only
#   ./start_home_server.sh --flutter    # Docker + flutter run (USB phone required)
#   ./start_home_server.sh --build      # Rebuild API image before start

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT/.env.home"
ENV_EXAMPLE="$ROOT/env.home.example"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"
RUN_FLUTTER=false
DOCKER_BUILD=""

for arg in "$@"; do
  case "$arg" in
    --flutter) RUN_FLUTTER=true ;;
    --build) DOCKER_BUILD="--build" ;;
    -h|--help)
      echo "Usage: $0 [--flutter] [--build]"
      echo "  --flutter  Run 'flutter run' after API is healthy (phone via USB)"
      echo "  --build    Rebuild Docker images"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

get_lan_ip() {
  hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.' | grep -v '^172\.17\.' | head -n1
}

echo ""
echo "=== MarGem Home Server ==="
echo ""

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Install: sudo apt install docker.io docker-compose-plugin" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running. Try: sudo systemctl start docker" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created .env.home"
    echo "Edit passwords, Azure connection string, and ALLOWED_HOSTS, then re-run."
    exit 1
  fi
  echo "Missing .env.home — copy env.home.example and configure it first." >&2
  exit 1
fi

LAN_IP="$(get_lan_ip || true)"
LAN_IP="${LAN_IP:-127.0.0.1}"
API_PORT="$(grep -E '^API_PORT=' "$ENV_FILE" | tail -n1 | cut -d= -f2- || true)"
API_PORT="${API_PORT:-8000}"
API_URL="http://${LAN_IP}:${API_PORT}"

echo "[1/2] Starting Postgres + API..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d $DOCKER_BUILD

echo "[2/2] Waiting for health..."
ready=false
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${API_PORT}/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done

echo ""
if [[ "$ready" == true ]]; then
  echo "=== Home server running ==="
else
  echo "API not ready yet. Check: docker compose -f docker-compose.home.yml logs api"
fi

echo ""
echo "  Same Wi-Fi:  $API_URL"
echo "  This machine: http://localhost:${API_PORT}"
echo "  Health:       http://localhost:${API_PORT}/health"
echo "  Images:       Azure Blob (cloud)"
echo ""
echo "Stop: ./stop_home_server.sh"
echo ""

if [[ "$RUN_FLUTTER" == true ]]; then
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Flutter not found. Install Flutter SDK or run without --flutter." >&2
    exit 1
  fi

  if command -v adb >/dev/null 2>&1; then
    devices="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
    if [[ -z "$devices" ]]; then
      echo "No USB phone detected (adb devices). Plug in phone with USB debugging on."
      echo "Or run manually:"
      echo "  cd mobile && flutter run --dart-define=API_BASE_URL=$API_URL"
      exit 1
    fi
  fi

  echo "Starting Flutter (Ctrl+C stops the app, API keeps running)..."
  echo ""
  cd "$ROOT/mobile"
  exec flutter run --dart-define=API_BASE_URL="$API_URL"
fi
