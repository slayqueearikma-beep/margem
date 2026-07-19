#!/usr/bin/env bash
# Pair and connect an Android phone for wireless Flutter debugging (Android 11+).
# Phone and this server must be on the same Wi-Fi.
#
# Usage:
#   ./setup_wireless_adb.sh pair 192.168.11.107:37123 123456
#   ./setup_wireless_adb.sh connect 192.168.11.107:41293
#   ./setup_wireless_adb.sh status
#   ./setup_wireless_adb.sh disconnect

set -euo pipefail

# Common Android SDK locations on Linux
for dir in "$HOME/Android/platform-tools" "$HOME/Android/Sdk/platform-tools"; do
  if [[ -d "$dir" ]]; then
    export PATH="$dir:$PATH"
  fi
done

usage() {
  echo "Usage:"
  echo "  $0 pair <ip:pairing_port> <6-digit-code>   # first time only"
  echo "  $0 connect <ip:debug_port>                  # after pair (or to reconnect)"
  echo "  $0 status"
  echo "  $0 disconnect"
  echo ""
  echo "On phone: Settings → Developer options → Wireless debugging"
  echo "  1. Tap 'Pair device with pairing code' → use pair command"
  echo "  2. Note 'IP address & port' on main screen → use connect command"
  exit 1
}

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install platform-tools and add to PATH:" >&2
  echo "  sudo apt install adb" >&2
  echo "  export PATH=\"\$HOME/Android/platform-tools:\$PATH\"" >&2
  exit 1
fi

cmd="${1:-}"
shift || true

case "$cmd" in
  pair)
    [[ $# -eq 2 ]] || usage
    target="$1"
    code="$2"
    echo "Pairing with $target ..."
    adb pair "$target" "$code"
  ;;
  connect)
    [[ $# -eq 1 ]] || usage
    target="$1"
    echo "Connecting to $target ..."
    adb connect "$target"
    echo ""
    adb devices -l
  ;;
  status)
    adb devices -l
    if command -v flutter >/dev/null 2>&1; then
      echo ""
      flutter devices
    fi
  ;;
  disconnect)
    adb disconnect
    adb devices -l
  ;;
  *)
    usage
    ;;
esac
