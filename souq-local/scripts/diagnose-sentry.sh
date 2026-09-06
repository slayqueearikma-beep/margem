#!/usr/bin/env bash
# End-to-end Sentry diagnostics (never prints secrets).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/infra/onprem/.env.prod}"
APK="${APK:-$ROOT/mobile/build/app/outputs/flutter-apk/app-release.apk}"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }
ylw() { printf '\033[33m%s\033[0m\n' "$*"; }

_read_var() {
  local key="$1"
  [[ -f "$ENV_FILE" ]] || return 1
  local line
  line="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  local value="${line#*=}"
  value="${value%$'\r'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

echo "=== Sentry diagnostics ==="
echo "Env file: $ENV_FILE"
echo ""

# 1. DSN in .env.prod
dsn="$(_read_var SENTRY_DSN || true)"
if [[ -z "$dsn" ]]; then
  red "FAIL: SENTRY_DSN is empty or missing in $ENV_FILE"
  echo "  Set: SENTRY_DSN=https://<key>@o<org>.ingest.sentry.io/<project>"
  exit 1
fi
if [[ "$dsn" != https://*@*sentry.io/* ]] && [[ "$dsn" != https://*@*ingest.*.sentry.io/* ]]; then
  ylw "WARN: SENTRY_DSN format looks unusual (expected https://KEY@o....ingest...sentry.io/PROJECT)"
else
  grn "OK: SENTRY_DSN format looks valid ($(printf '%s' "$dsn" | wc -c) chars)"
fi

# Extract ingest host for connectivity test (no key printed)
ingest_host="$(printf '%s' "$dsn" | sed -E 's#^https://[^@]+@([^/]+)/.*#\1#')"
if [[ -z "$ingest_host" || "$ingest_host" == "$dsn" ]]; then
  red "FAIL: could not parse ingest host from DSN"
  exit 1
fi
echo "Ingest host: $ingest_host"

# 2. Network reachability (from build server)
if curl -fsS --max-time 10 "https://${ingest_host}/" -o /dev/null 2>/dev/null; then
  grn "OK: ingest host reachable from this machine (HTTPS)"
else
  ylw "WARN: could not reach https://${ingest_host}/ from this machine (may still work from phone)"
fi

# 3. Build scripts see DSN
echo ""
echo "--- Mobile build scripts ---"
if "$SCRIPT_DIR/mobile-production-dart-defines.sh" --check-sentry; then
  grn "OK: build scripts load SENTRY_DSN"
else
  red "FAIL: build scripts cannot read SENTRY_DSN"
  exit 1
fi

# 4. APK check
echo ""
echo "--- Installed APK ---"
if [[ -f "$APK" ]]; then
  if strings "$APK" 2>/dev/null | grep -q 'ingest.*sentry\.io'; then
    grn "OK: APK contains ingest.sentry.io (DSN baked in)"
  else
    red "FAIL: APK does NOT contain ingest.sentry.io"
    echo "  Rebuild: SENTRY_VERIFY_TEST=true BUILD_TARGET=apk ./scripts/build-production-android.sh"
    echo "  Do NOT use manual flutter build apk without --dart-define=SENTRY_DSN=..."
  fi
  if strings "$APK" 2>/dev/null | grep -q 'dribex_sentry_verify'; then
    grn "OK: APK built with SENTRY_VERIFY_TEST (verify string present)"
  else
    ylw "WARN: APK was NOT built with SENTRY_VERIFY_TEST=true"
    echo "  Normal app launch sends NOTHING to Sentry until a crash/error occurs."
    echo "  Rebuild: SENTRY_VERIFY_TEST=true BUILD_TARGET=apk ./scripts/build-production-android.sh"
  fi
else
  ylw "WARN: APK not found at $APK — skip binary check"
fi

# 5. Backend live send (optional)
echo ""
echo "--- Backend live test (optional) ---"
compose_dir="$ROOT/infra/onprem"
if [[ -f "$compose_dir/docker-compose.prod.yml" ]] && command -v docker >/dev/null 2>&1; then
  if docker compose -f "$compose_dir/docker-compose.prod.yml" --env-file "$ENV_FILE" ps api 2>/dev/null | grep -q 'running\|Up'; then
  docker compose -f "$compose_dir/docker-compose.prod.yml" --env-file "$ENV_FILE" exec -T api \
    python -c "
import os
dsn = (os.environ.get('SENTRY_DSN') or '').strip()
assert dsn, 'SENTRY_DSN empty in api container'
import sentry_sdk
sentry_sdk.init(dsn=dsn, environment='production')
sentry_sdk.capture_message('dribex_backend_sentry_verify', level='error')
sentry_sdk.flush(timeout=5)
print('sent backend test event: dribex_backend_sentry_verify')
" && grn "OK: backend test event sent — check Sentry Issues for dribex_backend_sentry_verify"
  else
    ylw "SKIP: api container not running"
  fi
else
  ylw "SKIP: docker compose not available"
fi

echo ""
echo "=== Sentry UI checklist ==="
echo "1. Open Issues (not only this Overview dashboard)"
echo "2. Time range: Last 24 hours (not 1H if you tested earlier)"
echo "3. Environment: All Envs"
echo "4. Search: dribex_sentry_verify OR dribex_backend_sentry_verify"
echo "5. Confirm DSN in .env.prod is from THIS Sentry project (Settings → Client Keys)"
echo ""
echo "After installing verify APK: open app, wait 15 seconds, then refresh Issues."
