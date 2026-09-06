#!/usr/bin/env bash
# Read-only audit: Docker published ports, listeners, DOCKER-USER, UFW.
# Run on the production Ubuntu host. Does not modify anything.
set -euo pipefail

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-/tmp/dribex-docker-audit-$STAMP.txt}"

exec > >(tee "$OUT") 2>&1

echo "=== Dribex Docker exposure audit ==="
echo "timestamp=$STAMP"
echo "hostname=$(hostname)"
echo ""

section() { echo ""; echo "--- $1 ---"; }

section "Docker containers and published ports"
if command -v docker >/dev/null; then
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}' || true
else
  echo "docker not installed"
fi

section "Host listeners (ss)"
sudo ss -lntup 2>/dev/null || ss -lntup

section "Docker networks"
docker network ls 2>/dev/null || true
for net in $(docker network ls --format '{{.Name}}' 2>/dev/null | rg 'margem|dribex|onprem|internal|edge' || true); do
  echo "Network: $net"
  docker network inspect "$net" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || true
done

section "iptables DOCKER-USER"
if sudo iptables -L DOCKER-USER -n -v --line-numbers 2>/dev/null; then
  :
else
  echo "DOCKER-USER chain missing or iptables unavailable"
fi

section "iptables DOCKER (nat)"
sudo iptables -t nat -L DOCKER -n -v --line-numbers 2>/dev/null | head -40 || true

section "iptables FORWARD (first 30 lines)"
sudo iptables -L FORWARD -n -v --line-numbers 2>/dev/null | head -30 || true

section "UFW status"
sudo ufw status verbose 2>/dev/null || echo "ufw not available"

section "Tailscale"
if command -v tailscale >/dev/null; then
  tailscale status 2>/dev/null | head -5 || true
  tailscale serve status 2>/dev/null || true
else
  echo "tailscale not installed"
fi

section "Compose port mappings (repo checkout)"
ROOT="${COMPOSE_ROOT:-$HOME/MarGem/souq-local/infra/onprem}"
if [[ -f "$ROOT/docker-compose.prod.yml" ]]; then
  rg -n '^\s+ports:|^\s+- "' "$ROOT/docker-compose.prod.yml" || true
else
  echo "compose file not found at $ROOT/docker-compose.prod.yml"
fi

section "Rendered compose ports (if stack running)"
if [[ -f "$ROOT/docker-compose.prod.yml" && -f "$ROOT/.env.prod" ]]; then
  docker compose -f "$ROOT/docker-compose.prod.yml" --env-file "$ROOT/.env.prod" config 2>/dev/null \
    | rg -n 'published:|target:|mode:' || true
fi

echo ""
echo "Audit saved to: $OUT"
echo "Review any 0.0.0.0 listeners besides :80 and :443."
