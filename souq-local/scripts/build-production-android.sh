#!/usr/bin/env bash
# Build production Android App Bundle
set -euo pipefail
cd "$(dirname "$0")/../mobile"

API_URL="${API_BASE_URL:-https://api.dribex.ma}"
SENTRY="${SENTRY_DSN:-}"
PRIVACY="${PRIVACY_POLICY_URL:-https://dribex.ma/legal/fr/privacy}"
MAPS_KEY="${GOOGLE_MAPS_API_KEY:-}"

if [[ -z "$MAPS_KEY" ]]; then
  echo "Warning: GOOGLE_MAPS_API_KEY not set — maps will be disabled on Android unless in local.properties"
fi

flutter clean
flutter pub get
flutter build appbundle --release \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL="$API_URL" \
  --dart-define=QR_PUBLIC_BASE_URL=https://qr.dribex.ma \
  --dart-define=PRIVACY_POLICY_URL="$PRIVACY" \
  ${SENTRY:+--dart-define=SENTRY_DSN="$SENTRY"} \
  ${MAPS_KEY:+--dart-define=GOOGLE_MAPS_API_KEY="$MAPS_KEY"}

echo "AAB: build/app/outputs/bundle/release/app-release.aab"
