#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/web"

if command -v ss >/dev/null 2>&1; then
  if ss -ltn 2>/dev/null | grep -q ':3000 '; then
    echo "ERROR: Port 3000 is already in use."
    echo "Stop the other process first (often margem-web from docker compose):"
    ss -ltnp 2>/dev/null | grep ':3000 ' || true
    echo ""
    echo "  docker compose -f \"$ROOT/docker-compose.yml\" stop web"
    exit 1
  fi
fi

if [[ ! -d node_modules/next ]]; then
  echo "Installing web dependencies (first run)..."
  npm install
fi

if [[ ! -f .env.local ]] && [[ -f env.example ]]; then
  cp env.example .env.local
  echo "Created web/.env.local from env.example"
fi

# Load env for HOSTNAME/PORT
if [[ -f .env.local ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.local
  set +a
fi

LAN_IP=""
if command -v hostname >/dev/null 2>&1; then
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

echo ""
echo "Starting Dribex web dev server..."
echo "  Bind: ${HOSTNAME:-0.0.0.0}:${PORT:-3000}"
echo ""
echo "Open in a browser ON THIS MACHINE:"
echo "  http://127.0.0.1:${PORT:-3000}"
echo ""
if [[ -n "$LAN_IP" ]]; then
  echo "Open from phone / another PC on the same Wi‑Fi:"
  echo "  http://${LAN_IP}:${PORT:-3000}"
  echo ""
  echo "If the page loads but listings are empty, set in web/.env.local:"
  echo "  NEXT_PUBLIC_API_BASE_URL=http://${LAN_IP}:8000"
  echo "  NEXT_PUBLIC_SITE_URL=http://${LAN_IP}:${PORT:-3000}"
  echo "Then restart npm run dev."
  echo ""
  echo "Ensure the API allows your origin — add to souq-local/.env or compose CORS_ORIGINS:"
  echo "  http://${LAN_IP}:${PORT:-3000}"
fi
echo "Wait until you see: ✓ Ready"
echo ""

exec npm run dev
