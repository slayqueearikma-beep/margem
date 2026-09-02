#!/usr/bin/env bash
# Production mobile run — same dart-defines as release builds.
# Usage: ./scripts/flutter-production-run.sh [--release] [extra flutter run args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mobile-production-dart-defines.sh
source "$SCRIPT_DIR/mobile-production-dart-defines.sh"

cd "$SCRIPT_DIR/../mobile"

MODE=(run)
if [[ "${1:-}" == "--release" ]]; then
  MODE=(run --release)
  shift
fi

flutter pub get
exec flutter "${MODE[@]}" "${MOBILE_DART_DEFINES[@]}" "$@"
