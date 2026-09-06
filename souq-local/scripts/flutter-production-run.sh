#!/usr/bin/env bash
# Production mobile run — same dart-defines as release builds.
# Usage: ./scripts/flutter-production-run.sh [--release] [extra flutter run args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mobile-production-dart-defines.sh
source "$SCRIPT_DIR/mobile-production-dart-defines.sh"

if ! "$SCRIPT_DIR/mobile-production-dart-defines.sh" --check-google-oauth; then
  echo >&2
  echo "Fix: add to $ENV_FILE on THIS computer (not only on the Pi):" >&2
  echo "  GOOGLE_OAUTH_CLIENT_IDS=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" >&2
  echo "  GOOGLE_OAUTH_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com" >&2
  echo "Then run: ./scripts/diagnose-google-oauth.sh" >&2
  exit 1
fi

cd "$SCRIPT_DIR/../mobile"

MODE=(run)
if [[ "${1:-}" == "--release" ]]; then
  MODE=(run --release)
  shift
fi

flutter pub get
exec flutter "${MODE[@]}" "${MOBILE_DART_DEFINES[@]}" "$@"
