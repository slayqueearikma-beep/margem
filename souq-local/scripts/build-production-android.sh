#!/usr/bin/env bash
# Build production Android release (APK, AAB, or both).
# Reads SENTRY_DSN from infra/onprem/.env.prod when not exported.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mobile-production-dart-defines.sh
source "$SCRIPT_DIR/mobile-production-dart-defines.sh"

cd "$SCRIPT_DIR/../mobile"

BUILD_TARGET="${BUILD_TARGET:-appbundle}"

if [[ -z "${SENTRY_DSN:-}" ]]; then
  echo "Warning: SENTRY_DSN not set — Sentry will be disabled in this build"
elif [[ -z "${GOOGLE_MAPS_API_KEY:-}" ]]; then
  echo "Warning: GOOGLE_MAPS_API_KEY not set — maps may be disabled on Android unless in local.properties"
fi

flutter pub get

_build_apk() {
  flutter build apk --release "${MOBILE_DART_DEFINES[@]}"
  echo "APK: build/app/outputs/flutter-apk/app-release.apk"
}

_build_aab() {
  flutter build appbundle --release "${MOBILE_DART_DEFINES[@]}"
  echo "AAB: build/app/outputs/bundle/release/app-release.aab"
}

case "$BUILD_TARGET" in
  apk) _build_apk ;;
  appbundle) _build_aab ;;
  both)
    _build_apk
    _build_aab
    ;;
  *)
    echo "BUILD_TARGET must be apk, appbundle, or both (got: $BUILD_TARGET)" >&2
    exit 1
    ;;
esac

if [[ -n "${SENTRY_DSN:-}" ]]; then
  echo "Sentry: enabled in build (DSN from environment or .env.prod)"
else
  echo "Sentry: disabled (no DSN)"
fi
