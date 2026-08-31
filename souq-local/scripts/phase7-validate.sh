#!/usr/bin/env bash
# Phase 7 — pre-production validation (home LAN or staging URLs).
# Usage:
#   API_URL=http://100.80.43.124:8000 \
#   WEB_URL=http://100.80.43.124:3000 \
#   ./scripts/phase7-validate.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_URL="${API_URL:-http://127.0.0.1:8000}"
WEB_URL="${WEB_URL:-http://127.0.0.1:3000}"
ADMIN_URL="${ADMIN_URL:-}"
ADMIN_BASIC_USER="${ADMIN_BASIC_USER:-}"
ADMIN_BASIC_PASSWORD="${ADMIN_BASIC_PASSWORD:-}"

pass=0
fail=0
skip=0

green() { printf '\033[32m✓\033[0m %s\n' "$1"; }
red() { printf '\033[31m✗\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m-\033[0m %s\n' "$1"; }

check() {
  local name="$1"
  shift
  if "$@"; then
    green "$name"
    pass=$((pass + 1))
  else
    red "$name"
    fail=$((fail + 1))
  fi
}

skip_check() {
  yellow "SKIP: $1"
  skip=$((skip + 1))
}

curl_status() {
  curl -fsS -o /dev/null -w '%{http_code}' "$1"
}

curl_json_detail() {
  curl -fsS "$1" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("detail",""))' 2>/dev/null || true
}

echo "==> Phase 7 validation"
echo "    API:  $API_URL"
echo "    WEB:  $WEB_URL"
[[ -n "$ADMIN_URL" ]] && echo "    ADMIN: $ADMIN_URL"
echo ""

check "API /ready" test "$(curl_status "$API_URL/ready")" = "200"
check "API /health" test "$(curl_status "$API_URL/health")" = "200"

auth_detail="$(curl -fsS "$API_URL/auth/me" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("detail",""))' 2>/dev/null || curl -s "$API_URL/auth/me" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("detail",""))' 2>/dev/null || true)"
if [[ "$auth_detail" == "Missing bearer token" ]]; then
  green "API /auth/me rejects unauthenticated access"
  pass=$((pass + 1))
else
  red "API /auth/me rejects unauthenticated access (got: ${auth_detail:-HTTP error})"
  fail=$((fail + 1))
fi

proxy_block_code="$(curl -s -o /dev/null -w '%{http_code}' "$WEB_URL/api-proxy/auth/me" || true)"
if [[ "$proxy_block_code" == "403" ]]; then
  green "Web proxy blocks /api-proxy/auth/me"
  pass=$((pass + 1))
else
  red "Web proxy blocks /api-proxy/auth/me (HTTP $proxy_block_code, expected 403)"
  fail=$((fail + 1))
fi

proxy_ok_code="$(curl -s -o /dev/null -w '%{http_code}' "$WEB_URL/api-proxy/categories" || true)"
if [[ "$proxy_ok_code" == "200" ]]; then
  green "Web proxy allows /api-proxy/categories"
  pass=$((pass + 1))
else
  red "Web proxy allows /api-proxy/categories (HTTP $proxy_ok_code, expected 200)"
  fail=$((fail + 1))
fi

web_home_code="$(curl -s -o /dev/null -w '%{http_code}' "$WEB_URL/" || true)"
if [[ "$web_home_code" == "200" ]]; then
  green "Web storefront homepage loads"
  pass=$((pass + 1))
else
  red "Web storefront homepage loads (HTTP $web_home_code)"
  fail=$((fail + 1))
fi

headers="$(curl -sI "$WEB_URL/" || true)"
if echo "$headers" | grep -qi 'x-frame-options: deny'; then
  green "Web sends X-Frame-Options: DENY"
  pass=$((pass + 1))
else
  red "Web sends X-Frame-Options: DENY"
  fail=$((fail + 1))
fi

if echo "$headers" | grep -qi 'content-security-policy:'; then
  green "Web sends Content-Security-Policy"
  pass=$((pass + 1))
else
  red "Web sends Content-Security-Policy"
  fail=$((fail + 1))
fi

if [[ -n "$ADMIN_URL" && -n "$ADMIN_BASIC_USER" && -n "$ADMIN_BASIC_PASSWORD" ]]; then
  admin_code="$(curl -s -o /dev/null -w '%{http_code}' -u "$ADMIN_BASIC_USER:$ADMIN_BASIC_PASSWORD" "$ADMIN_URL/" || true)"
  if [[ "$admin_code" == "200" ]]; then
    green "Admin dashboard Basic Auth gate"
    pass=$((pass + 1))
  else
    red "Admin dashboard Basic Auth gate (HTTP $admin_code)"
    fail=$((fail + 1))
  fi
else
  skip_check "Admin dashboard (set ADMIN_URL + ADMIN_BASIC_USER + ADMIN_BASIC_PASSWORD)"
fi

echo ""
echo "==> Automated test suites (local repo)"
if command -v python3 >/dev/null 2>&1; then
  if (cd "$ROOT/backend" && python3 -m pytest tests/test_web_storefront_security.py -q --tb=no >/tmp/phase7-pytest.log 2>&1); then
    green "Backend web security tests"
    pass=$((pass + 1))
  else
    red "Backend web security tests (see /tmp/phase7-pytest.log)"
    fail=$((fail + 1))
  fi
else
  skip_check "Backend tests (python3 not found)"
fi

if command -v node >/dev/null 2>&1 && [[ -f "$ROOT/web/scripts/test-security.mjs" ]]; then
  if (cd "$ROOT/web" && node --test scripts/test-security.mjs >/tmp/phase7-node.log 2>&1); then
    green "Web security unit tests"
    pass=$((pass + 1))
  else
    red "Web security unit tests (see /tmp/phase7-node.log)"
    fail=$((fail + 1))
  fi
else
  skip_check "Web security unit tests (node not found)"
fi

echo ""
echo "==> Summary: $pass passed, $fail failed, $skip skipped"
if [[ "$fail" -gt 0 ]]; then
  echo "Phase 7: NOT READY — fix failures above before staging soak."
  exit 1
fi
echo "Phase 7 automated checks: PASS"
echo "Next: complete manual checklist in docs/PHASE7_PREPRODUCTION_VALIDATION.md"
