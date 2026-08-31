#!/usr/bin/env bash
# Repository-side production safety checks for open public beta.
# Does NOT verify live DNS/TLS — only that release configuration cannot
# silently fall back to development endpoints.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0

green() { printf '\033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
red() { printf '\033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }

check() {
  local name="$1"
  shift
  if "$@"; then
    green "$name"
  else
    red "$name"
  fi
}

check_absent() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if rg -q "$pattern" "$file" 2>/dev/null; then
    red "$name"
  else
    green "$name"
  fi
}

check_absent_in() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  check_absent "$name" "$pattern" "$file"
}

echo "==> Dribex production safety validation (repository)"
echo ""

echo "==> Mobile production safety"
check "Mobile release script uses https://api.dribex.ma" \
  rg -q 'API_BASE_URL.*https://api\.dribex\.ma' "$ROOT/scripts/build-production-android.sh"
check "Mobile AppConfig defines production API URL" \
  rg -q "productionApiBaseUrl = 'https://api\.dribex\.ma'" "$ROOT/mobile/lib/core/config/app_config.dart"
check "Mobile AppConfig rejects dev hosts in release validation" \
  rg -q 'isDevelopmentApiHost' "$ROOT/mobile/lib/core/config/app_config.dart"
check "Mobile release tests cover production API validation" \
  rg -q 'validateReleaseApiBaseUrl' "$ROOT/mobile/test/api_base_url_test.dart"
check "CI mobile release build uses api.dribex.ma" \
  rg -q 'dart-define=API_BASE_URL=https://api\.dribex\.ma' "$ROOT/../.github/workflows/margem-ci.yml"

echo ""
echo "==> Web production safety"
check "Web Dockerfile requires NEXT_PUBLIC_API_BASE_URL" \
  rg -q 'test -n "\$NEXT_PUBLIC_API_BASE_URL"' "$ROOT/web/Dockerfile"
check_absent_in "Web Dockerfile has no localhost API default" \
  'ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:8000' "$ROOT/web/Dockerfile"
check "Web production validator script exists" \
  test -f "$ROOT/web/scripts/validate-production-config.mjs"
if (cd "$ROOT/web" && npm run -s validate:production >/dev/null 2>&1); then
  green "Web validate:production passes with canonical URLs"
else
  red "Web validate:production passes with canonical URLs"
fi
check "Web config preserves /api-proxy architecture" \
  rg -q '/api-proxy' "$ROOT/web/src/lib/config.ts"

echo ""
echo "==> Deep links"
check "Android manifest uses dribex.ma" \
  rg -q 'android:host="dribex\.ma"' "$ROOT/mobile/android/app/src/main/AndroidManifest.xml"
check_absent_in "Android manifest does not reference margem.ma" \
  'margem\.ma' "$ROOT/mobile/android/app/src/main/AndroidManifest.xml"
check "iOS URL scheme uses dribex" \
  rg -q '<string>dribex</string>' "$ROOT/mobile/ios/Runner/Info.plist"
check "Mobile runtime deep links use dribex:// scheme" \
  rg -q "dribex://seller/boost" "$ROOT/mobile/lib/core/services/api_service.dart"

echo ""
echo "==> Production environment templates"
check "env.production.example disables payments for beta" \
  rg -q '^PAYMENTS_ENABLED=false' "$ROOT/env.production.example"
check "env.production.example uses PAYMENT_PROVIDER=none" \
  rg -q '^PAYMENT_PROVIDER=none' "$ROOT/env.production.example"
check_absent_in "env.production.example has no localhost hosts" \
  'localhost|127\.0\.0\.1|10\.0\.2\.2' "$ROOT/env.production.example"
check "infra env.prod.example validates via script" \
  test -x "$ROOT/infra/onprem/scripts/validate-production-env.sh"

echo ""
echo "==> Docker / nginx configuration (static review)"
check "Production compose injects PUBLIC_API_URL into web build" \
  rg -q 'NEXT_PUBLIC_API_BASE_URL: \$\{PUBLIC_API_URL\}' "$ROOT/infra/onprem/docker-compose.prod.yml"
check "Nginx config defines api.dribex.ma and dribex.ma" \
  rg -q 'server_name dribex\.ma www\.dribex\.ma' "$ROOT/infra/onprem/nginx/nginx.conf" \
  && rg -q 'server_name api\.dribex\.ma' "$ROOT/infra/onprem/nginx/nginx.conf"
check "Nginx redirects HTTP to HTTPS" \
  rg -q 'return 301 https://' "$ROOT/infra/onprem/nginx/nginx.conf"
check "Nginx exposes /storage/ proxy" \
  rg -q 'location /storage/' "$ROOT/infra/onprem/nginx/nginx.conf"

echo ""
echo "==> Summary: $pass passed, $fail failed"
if [[ "$fail" -gt 0 ]]; then
  echo "Production safety validation: FAIL"
  exit 1
fi
echo "Production safety validation: PASS"
echo "Note: live DNS/TLS/CORS/storage/email remain manual deployment checks."
