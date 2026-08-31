#!/usr/bin/env bash
# Phase 8 — production readiness validation (run before go-live).
# Usage:
#   ./scripts/phase8-production-readiness.sh
# Optional live checks against a deployed stack:
#   API_URL=https://api.dribex.ma WEB_URL=https://dribex.ma ./scripts/phase8-production-readiness.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_URL="${API_URL:-}"
WEB_URL="${WEB_URL:-}"

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

echo "==> Phase 8 production readiness validation"
echo ""

echo "==> Repository configuration checks"
check "env.production.example exists" test -f "$ROOT/env.production.example"
check "env.staging.example exists" test -f "$ROOT/env.staging.example"
check "backend/.env.example exists" test -f "$ROOT/backend/.env.example"
check "on-prem prod compose exists" test -f "$ROOT/infra/onprem/docker-compose.prod.yml"
check "backup script exists" test -x "$ROOT/scripts/backup_home_db.sh" -o -f "$ROOT/infra/onprem/scripts/backup.sh"

if rg -n 'localhost|127\.0\.0\.1|192\.168\.|100\.80\.' "$ROOT/env.production.example" >/dev/null 2>&1; then
  red "env.production.example contains development-only hosts"
  fail=$((fail + 1))
else
  green "env.production.example has no development-only hosts"
  pass=$((pass + 1))
fi

if rg -n 'CORS_ORIGINS=\*' "$ROOT/env.production.example" >/dev/null 2>&1; then
  red "env.production.example uses wildcard CORS"
  fail=$((fail + 1))
else
  green "env.production.example avoids wildcard CORS"
  pass=$((pass + 1))
fi

echo ""
echo "==> Automated test suites"
if command -v python3 >/dev/null 2>&1; then
  if (cd "$ROOT/backend" && PYTHONPATH=. python3 -m pytest \
      tests/test_production_hardening.py \
      tests/test_migration_chain.py \
      tests/test_web_storefront_security.py \
      -q --tb=no >/tmp/phase8-pytest.log 2>&1); then
    green "Backend production hardening + migration tests"
    pass=$((pass + 1))
  else
    red "Backend production hardening + migration tests (see /tmp/phase8-pytest.log)"
    fail=$((fail + 1))
  fi
else
  skip_check "Backend tests (python3 not found)"
fi

if command -v node >/dev/null 2>&1 && [[ -f "$ROOT/web/scripts/test-security.mjs" ]]; then
  if (cd "$ROOT/web" && node --test scripts/test-security.mjs >/tmp/phase8-node.log 2>&1); then
    green "Web security unit tests"
    pass=$((pass + 1))
  else
    red "Web security unit tests (see /tmp/phase8-node.log)"
    fail=$((fail + 1))
  fi
else
  skip_check "Web security unit tests (node not found)"
fi

if command -v docker >/dev/null 2>&1; then
  if (cd "$ROOT" && docker compose -f infra/onprem/docker-compose.prod.yml \
      --env-file infra/onprem/env.prod.example config >/dev/null 2>&1); then
    green "Production compose config validates"
    pass=$((pass + 1))
  else
    red "Production compose config validates"
    fail=$((fail + 1))
  fi
else
  skip_check "Production compose validation (docker not found)"
fi

echo ""
echo "==> Production safety checks"
if [[ -x "$ROOT/scripts/validate-production-safety.sh" ]]; then
  if "$ROOT/scripts/validate-production-safety.sh"; then
    green "Repository production safety script"
    pass=$((pass + 1))
  else
    red "Repository production safety script"
    fail=$((fail + 1))
  fi
else
  red "Repository production safety script missing"
  fail=$((fail + 1))
fi

echo ""
if [[ -n "$API_URL" ]]; then
  echo "==> Live API checks ($API_URL)"
  check "API /ready" test "$(curl -fsS -o /dev/null -w '%{http_code}' "$API_URL/ready" 2>/dev/null || echo 000)" = "200"
  openapi_code="$(curl -s -o /dev/null -w '%{http_code}' "$API_URL/openapi.json" 2>/dev/null || echo 000)"
  if [[ "$openapi_code" == "404" || "$openapi_code" == "403" ]]; then
    green "OpenAPI not exposed publicly"
    pass=$((pass + 1))
  else
    red "OpenAPI not exposed publicly (HTTP $openapi_code)"
    fail=$((fail + 1))
  fi
else
  skip_check "Live API checks (set API_URL=https://api.dribex.ma)"
fi

if [[ -n "$WEB_URL" ]]; then
  echo ""
  echo "==> Live web checks ($WEB_URL)"
  check "Web homepage" test "$(curl -fsS -o /dev/null -w '%{http_code}' "$WEB_URL/" 2>/dev/null || echo 000)" = "200"
else
  skip_check "Live web checks (set WEB_URL=https://dribex.ma)"
fi

echo ""
echo "==> Known production blockers (manual verification required)"
yellow "Cloudflare tunnel / DNS must be live before public launch"
yellow "Database backup restore procedure must be tested on a non-production clone"
yellow "NAPS and Brevo credentials must be injected on the server only (never in git)"
yellow "REDIS_URL required when running more than one API replica"
yellow "ADMIN_IP_ALLOWLIST must restrict admin access to office/VPN CIDRs only"

echo ""
echo "==> Summary: $pass passed, $fail failed, $skip skipped"
if [[ "$fail" -gt 0 ]]; then
  echo "Phase 8: NOT READY — fix failures above before production launch."
  exit 1
fi
echo "Phase 8 automated checks: PASS"
echo "Complete the manual checklist in docs/PHASE8_PRODUCTION_READINESS.md before go-live."
