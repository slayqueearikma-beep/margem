#!/usr/bin/env bash
# Verify production Sentry wiring without printing the DSN.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mobile-production-dart-defines.sh
source "$SCRIPT_DIR/mobile-production-dart-defines.sh"

echo "==> 1. Check SENTRY_DSN is available to build scripts"
"$SCRIPT_DIR/mobile-production-dart-defines.sh" --check-sentry

echo ""
echo "==> 2. Compile-time check (CrashReporting.isConfigured)"
cd "$SCRIPT_DIR/../mobile"
flutter pub get
flutter test test/crash_reporting_config_test.dart "${MOBILE_DART_DEFINES[@]}"

echo ""
echo "==> 3. Optional live test event (device/emulator required)"
echo "Run on a connected device:"
echo "  SENTRY_VERIFY_TEST=true ./scripts/flutter-production-run.sh --release"
echo "Then open the Sentry project → Issues and confirm event: dribex_sentry_verify"

if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | rg -q 'device$'; then
  echo ""
  echo "Device detected. Send a live verification event with:"
  echo "  SENTRY_VERIFY_TEST=true ./scripts/flutter-production-run.sh --release"
  echo "Launch the app once, then check Sentry for: dribex_sentry_verify"
else
  echo ""
  echo "No adb device — build and install manually:"
  echo "  SENTRY_VERIFY_TEST=true BUILD_TARGET=apk ./scripts/build-production-android.sh"
  echo "  adb install -r mobile/build/app/outputs/flutter-apk/app-release.apk"
fi
