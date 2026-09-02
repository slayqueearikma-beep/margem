#!/usr/bin/env bash
# Fail if production compose publishes dangerous host ports.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE="$ROOT/docker-compose.prod.yml"
FAIL=0

deny_ports=(5432 6379 9000 9090 8200 3100 3000 8000)

if [[ ! -f "$COMPOSE" ]]; then
  echo "Missing $COMPOSE" >&2
  exit 1
fi

# Only nginx may publish host ports in production compose.
while IFS= read -r line; do
  for port in "${deny_ports[@]}"; do
    if echo "$line" | rg -q "\"0\\.0\\.0\\.0:${port}|:${port}:${port}|\"${port}:${port}"; then
      echo "FAIL: production compose must not publish port $port on host: $line" >&2
      FAIL=1
    fi
  done
done < <(rg '^\s+-\s+"[^"]+:[0-9]+"' "$COMPOSE" || true)

nginx_ports="$(rg '^\s+-\s+"' "$COMPOSE" | rg ':(80|443)"' || true)"
if [[ -z "$nginx_ports" ]]; then
  echo "FAIL: expected nginx to publish 80 and 443" >&2
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "Production compose port policy: OK (nginx 80/443 only)"
