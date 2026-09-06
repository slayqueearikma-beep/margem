#!/usr/bin/env bash
# Server-side public production gate checks (run on the production host).
# Does not print secret values.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.prod}"
FAIL=0

pass() { printf '\033[32m✓\033[0m %s\n' "$1"; }
fail() { printf '\033[31m✗\033[0m %s\n' "$1"; FAIL=1; }

API_HOST="${PUBLIC_API_HOST:-api.dribex.ma}"
WEB_HOST="${PUBLIC_WEB_HOST:-dribex.ma}"

echo "==> Dribex public production gate (server)"
echo ""

if [[ -f "$ENV_FILE" ]]; then
  if "$ROOT/scripts/validate-production-env.sh" "$ENV_FILE"; then
    pass "Production environment file validates"
  else
    fail "Production environment file validation failed"
  fi
else
  fail "Missing $ENV_FILE"
fi

echo ""
echo "==> DNS (must not be Tailscale 100.x)"
for host in "$API_HOST" "$WEB_HOST" "www.dribex.ma"; do
  ip="$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1; exit}')"
  if [[ -z "$ip" ]]; then
    fail "DNS: $host does not resolve"
  elif [[ "$ip" == 100.* ]]; then
    fail "DNS: $host → $ip (Tailscale — not valid for public production)"
  else
    pass "DNS: $host → $ip"
  fi
done

echo ""
echo "==> TLS + HTTP"
for url in "https://${API_HOST}/ready" "https://${WEB_HOST}/"; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$url" || echo 000)"
  if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" || "$code" == "307" || "$code" == "308" ]]; then
    pass "HTTP $code $url"
  else
    fail "HTTP $code $url"
  fi
done

issuer="$(echo | openssl s_client -connect "${API_HOST}:443" -servername "$API_HOST" 2>/dev/null \
  | openssl x509 -noout -issuer 2>/dev/null || true)"
if echo "$issuer" | rg -qi 'self-signed|CN=api\.dribex\.ma.*CN=api\.dribex\.ma'; then
  fail "TLS: certificate appears self-signed — replace before public launch"
elif [[ -n "$issuer" ]]; then
  pass "TLS: $issuer"
else
  fail "TLS: could not read certificate for $API_HOST"
fi

echo ""
echo "==> Listeners (public ports)"
if sudo ss -lntp 2>/dev/null | rg -q ':443.*docker|:443.*nginx'; then
  pass "Port 443 owned by nginx/docker"
elif sudo ss -lntp 2>/dev/null | rg -q ':443.*tailscale'; then
  fail "Port 443 owned by tailscale — run: tailscale serve reset (see docs/TAILSCALE_PUBLIC_COEXISTENCE.md)"
else
  fail "Port 443 listener not identified"
fi

echo ""
echo "==> Docker stack"
COMPOSE="docker compose -f $ROOT/docker-compose.prod.yml --env-file $ENV_FILE"
if $COMPOSE ps --status running 2>/dev/null | rg -q 'nginx'; then
  pass "nginx container running"
else
  fail "nginx container not running"
fi
if $COMPOSE ps --status running 2>/dev/null | rg -q 'api'; then
  pass "api container running"
else
  fail "api container not running"
fi
if $COMPOSE ps --status running 2>/dev/null | rg -q 'web'; then
  pass "web container running"
else
  fail "web container not running"
fi

echo ""
echo "==> MinIO not publicly proxied"
if rg -q 'location /storage/' "$ROOT/nginx/nginx.conf" 2>/dev/null; then
  fail "nginx still exposes /storage/ MinIO bypass"
else
  pass "nginx has no /storage/ MinIO bypass"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "PUBLIC PRODUCTION GATE: PASS"
  exit 0
fi
echo "PUBLIC PRODUCTION GATE: FAIL"
exit 1
