#!/usr/bin/env bash
# Verify api.dribex.ma is reachable from the public Internet (not Tailscale-only).
# Run on the server and from a machine WITHOUT Tailscale/VPN.
set -euo pipefail

API_HOST="${API_HOST:-api.dribex.ma}"
WEB_HOST="${WEB_HOST:-dribex.ma}"
FAIL=0

warn() { echo "WARN: $*" >&2; }
fail() { echo "FAIL: $*" >&2; FAIL=1; }
ok() { echo "OK:   $*"; }

echo "=== Dribex public API connectivity check ==="
echo "Host: $API_HOST"
echo

resolve() {
  getent ahostsv4 "$1" 2>/dev/null | awk '{print $1}' | sort -u | head -5
}

api_ips="$(resolve "$API_HOST" || true)"
if [[ -z "$api_ips" ]]; then
  fail "DNS does not resolve for $API_HOST"
else
  ok "DNS for $API_HOST ->"
  echo "$api_ips" | sed 's/^/      /'
  while read -r ip; do
    [[ -z "$ip" ]] && continue
    if [[ "$ip" == 100.* ]]; then
      fail "$API_HOST points to Tailscale IP $ip — phones without Tailscale cannot connect"
      echo "      Fix: set DNS A record to your server's PUBLIC IP (not 100.x.x.x)" >&2
    fi
    if [[ "$ip" == 127.* ]]; then
      fail "$API_HOST points to loopback $ip"
    fi
  done <<< "$api_ips"
fi

echo
echo "=== HTTPS /ready ==="
if curl -fsS --max-time 12 "https://${API_HOST}/ready" >/tmp/dribex-ready.json 2>/tmp/dribex-ready.err; then
  ok "https://${API_HOST}/ready returned 200"
  head -c 200 /tmp/dribex-ready.json | tr '\n' ' '
  echo
else
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 12 "https://${API_HOST}/ready" 2>/dev/null || echo "000")
  fail "https://${API_HOST}/ready failed (HTTP $code)"
  sed 's/^/      /' /tmp/dribex-ready.err 2>/dev/null || true
fi

echo
echo "=== TLS certificate ==="
if echo | openssl s_client -connect "${API_HOST}:443" -servername "$API_HOST" 2>/dev/null \
  | openssl x509 -noout -subject -dates 2>/dev/null; then
  ok "Certificate presented for SNI $API_HOST"
else
  warn "Could not inspect certificate (connection may be blocked from this network)"
fi

echo
echo "=== Nginx port binding (on server only) ==="
if command -v ss >/dev/null 2>&1; then
  ss -tlnp 2>/dev/null | grep ':443 ' || warn "Nothing listening on :443 on this host"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo
  echo "Public mobile users need:"
  echo "  1. DNS A records for api.dribex.ma + dribex.ma -> PUBLIC IP (not 100.x.x.x)"
  echo "  2. nginx on 0.0.0.0:443 with a trusted TLS cert (Cloudflare origin or Let's Encrypt)"
  echo "  3. Firewall allows 80/443 on the public interface"
  echo "  4. Rebuild mobile with: --dart-define=PRODUCTION=true --dart-define=API_BASE_URL=https://api.dribex.ma"
  echo
  echo "See infra/onprem/PUBLIC_NETWORK.md for step-by-step instructions."
  exit 1
fi

ok "Public API checks passed from this network."
exit 0
