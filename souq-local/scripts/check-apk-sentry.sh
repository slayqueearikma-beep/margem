#!/usr/bin/env bash
# Check whether a release APK was built with Sentry DSN baked in (no secrets printed).
set -euo pipefail

APK="${1:-mobile/build/app/outputs/flutter-apk/app-release.apk}"

if [[ ! -f "$APK" ]]; then
  echo "APK not found: $APK" >&2
  echo "Build first: BUILD_TARGET=apk ./scripts/build-production-android.sh" >&2
  exit 1
fi

if strings "$APK" 2>/dev/null | grep -q 'ingest.*sentry\.io'; then
  echo "Sentry: DSN host found in APK (ingest.sentry.io)"
  exit 0
fi

echo "Sentry: NO ingest.sentry.io string in APK — rebuild with ./scripts/build-production-android.sh" >&2
exit 1
