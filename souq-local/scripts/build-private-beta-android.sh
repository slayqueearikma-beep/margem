#!/usr/bin/env bash
# Tailscale / private beta APK — accepts self-signed nginx TLS (not for store release).
set -euo pipefail
cd "$(dirname "$0")/../mobile"

API_URL="${API_BASE_URL:-https://api.dribex.ma}"

flutter pub get
flutter build apk --debug \
  --dart-define=API_BASE_URL="$API_URL" \
  --dart-define=ALLOW_INSECURE_TLS=true

echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
echo "Install: adb install -r build/app/outputs/flutter-apk/app-debug.apk"
