#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-3000}"

echo "=== Dribex web dev diagnostics ==="
echo ""

if command -v ss >/dev/null 2>&1; then
  echo "Listeners on port ${PORT}:"
  ss -ltnp 2>/dev/null | grep ":${PORT} " || echo "  (nothing listening on ${PORT})"
  echo ""
fi

if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx margem-web; then
  echo "Docker margem-web is running — use http://127.0.0.1:${PORT} or stop it to run npm run dev:"
  echo "  docker compose -f \"$ROOT/docker-compose.yml\" stop web"
  echo ""
fi

if curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
  echo "OK: http://127.0.0.1:${PORT}/ responds"
else
  echo "FAIL: http://127.0.0.1:${PORT}/ does not respond"
  echo "  Start dev: $ROOT/scripts/dev-web.sh"
  echo "  Or docker: docker compose -f \"$ROOT/docker-compose.yml\" up -d web"
fi

LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -n "$LAN_IP" ]]; then
  if curl -fsS --max-time 3 "http://${LAN_IP}:${PORT}/" >/dev/null 2>&1; then
    echo "OK: http://${LAN_IP}:${PORT}/ responds on LAN"
  else
    echo "FAIL: http://${LAN_IP}:${PORT}/ does not respond (firewall or wrong bind address)"
    echo "  Try: sudo ufw allow ${PORT}/tcp"
  fi
fi

echo ""
echo "API check:"
if curl -fsS --max-time 3 "http://127.0.0.1:8000/health" >/dev/null 2>&1; then
  echo "OK: API http://127.0.0.1:8000/health"
else
  echo "FAIL: API not reachable — run: docker compose -f \"$ROOT/docker-compose.yml\" up -d api"
fi
