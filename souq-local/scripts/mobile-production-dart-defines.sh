#!/usr/bin/env bash
# Shared --dart-define flags for production mobile builds (APK, AAB, flutter run).
# Sources SENTRY_DSN from infra/onprem/.env.prod when not already exported.
# Never prints secret values.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-env-prod-for-mobile.sh
source "$SCRIPT_DIR/load-env-prod-for-mobile.sh"

API_URL="${API_BASE_URL:-https://api.dribex.ma}"
PRIVACY="${PRIVACY_POLICY_URL:-${API_URL}/legal/fr/privacy}"
MAPS_KEY="${GOOGLE_MAPS_API_KEY:-}"
GOOGLE_OAUTH_ID="${GOOGLE_OAUTH_CLIENT_ID:-}"
SENTRY_VERIFY="${SENTRY_VERIFY_TEST:-}"

mobile_production_dart_defines() {
  MOBILE_DART_DEFINES=(
    "--dart-define=PRODUCTION=true"
    "--dart-define=API_BASE_URL=${API_URL}"
    "--dart-define=QR_PUBLIC_BASE_URL=https://qr.dribex.ma"
    "--dart-define=PRIVACY_POLICY_URL=${PRIVACY}"
  )
  if [[ -n "${SENTRY_DSN:-}" ]]; then
    MOBILE_DART_DEFINES+=("--dart-define=SENTRY_DSN=${SENTRY_DSN}")
  fi
  if [[ -n "$MAPS_KEY" ]]; then
    MOBILE_DART_DEFINES+=("--dart-define=GOOGLE_MAPS_API_KEY=${MAPS_KEY}")
  fi
  if [[ -n "$GOOGLE_OAUTH_ID" ]]; then
    MOBILE_DART_DEFINES+=("--dart-define=GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_ID}")
  fi
  if [[ -n "$SENTRY_VERIFY" ]]; then
    MOBILE_DART_DEFINES+=("--dart-define=SENTRY_VERIFY_TEST=${SENTRY_VERIFY}")
  fi
}

mobile_production_dart_defines

if [[ -z "$GOOGLE_OAUTH_ID" ]]; then
  echo "WARNING: GOOGLE_OAUTH_CLIENT_ID is not set — Google Sign-In will fail on device." >&2
  echo "  Add GOOGLE_OAUTH_CLIENT_ID to ${ENV_FILE} or export it before running." >&2
fi

if [[ "${1:-}" == "--check-sentry" ]]; then
  if [[ -n "${SENTRY_DSN:-}" ]]; then
    echo "SENTRY_DSN: configured"
    exit 0
  fi
  echo "SENTRY_DSN: not configured (set in environment or $ENV_FILE)" >&2
  exit 1
fi
