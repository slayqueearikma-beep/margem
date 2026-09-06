#!/usr/bin/env bash
# Check Google Sign-In configuration for mobile + backend.
# Does not print secret values — only whether keys are present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/infra/onprem/.env.prod}"
API_URL="${API_BASE_URL:-https://api.dribex.ma}"

echo "==> Google OAuth diagnostics"
echo "Env file: $ENV_FILE"
if [[ -f "$ENV_FILE" ]]; then
  echo "  .env.prod: found"
else
  echo "  .env.prod: MISSING on this computer"
  echo "  Copy infra/onprem/.env.prod from your Pi or create it locally with GOOGLE_OAUTH_CLIENT_ID."
fi

# shellcheck source=load-env-prod-for-mobile.sh
source "$SCRIPT_DIR/load-env-prod-for-mobile.sh"

if [[ -n "${GOOGLE_OAUTH_CLIENT_ID:-}" ]]; then
  echo "  GOOGLE_OAUTH_CLIENT_ID: configured (mobile dart-define)"
else
  echo "  GOOGLE_OAUTH_CLIENT_ID: NOT SET — app will show Google OAuth configuration error"
fi

if [[ -n "${GOOGLE_OAUTH_CLIENT_IDS:-}" ]]; then
  echo "  GOOGLE_OAUTH_CLIENT_IDS: configured (from env or .env.prod)"
else
  ids_line=""
  if [[ -f "$ENV_FILE" ]]; then
    ids_line="$(grep -E '^GOOGLE_OAUTH_CLIENT_IDS=' "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  fi
  if [[ -n "$ids_line" ]]; then
    echo "  GOOGLE_OAUTH_CLIENT_IDS: configured in .env.prod"
  else
    echo "  GOOGLE_OAUTH_CLIENT_IDS: not found locally"
  fi
fi

echo
echo "==> Mobile build (Flutter on THIS computer)"
echo "  Android package: com.margem.app"
echo "  GOOGLE_OAUTH_CLIENT_ID must be the Web OAuth client ID (serverClientId)."
echo "  Rebuild with: ./scripts/flutter-production-run.sh"
echo "  Debug SHA-1:"
echo "    keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1"

echo
echo "==> Backend API ($API_URL)"
health_code="$(curl -sS -o /tmp/dribex-health.json -w '%{http_code}' "$API_URL/health" || echo "000")"
echo "  GET /health -> HTTP $health_code"
if [[ "$health_code" == "200" ]]; then
  cat /tmp/dribex-health.json
  echo
fi

google_code="$(curl -sS -o /tmp/dribex-google.json -w '%{http_code}' \
  -X POST "$API_URL/auth/google" \
  -H 'Content-Type: application/json' \
  -d '{"id_token":"test","account_type":"buyer"}' || echo "000")"
echo "  POST /auth/google (probe) -> HTTP $google_code"
if [[ "$google_code" == "503" ]]; then
  echo "  Backend says Google Sign-In is NOT configured."
  echo "  On the Pi, set GOOGLE_OAUTH_CLIENT_IDS in .env.prod and recreate the api container."
elif [[ "$google_code" == "401" || "$google_code" == "422" ]]; then
  echo "  Backend Google auth endpoint is reachable (token rejected as expected)."
else
  echo "  Response: $(head -c 200 /tmp/dribex-google.json 2>/dev/null || true)"
fi

echo
echo "==> Google Cloud Console checklist"
echo "  1. OAuth client type Web application -> use as GOOGLE_OAUTH_CLIENT_ID + in GOOGLE_OAUTH_CLIENT_IDS"
echo "  2. OAuth client type Android -> package com.margem.app + SHA-1 from your keystore"
echo "  3. OAuth consent screen published (or add your Google account as test user)"
echo
echo "  Debug log filter while testing Google Sign-In:"
echo "    adb logcat | grep -iE 'DribexGoogleAuth|flutter'"
