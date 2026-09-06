#!/usr/bin/env bash
# Regenerate Dribex brand assets. Works on Ubuntu without system-wide pip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if python3 -c "import PIL" 2>/dev/null; then
  exec python3 scripts/generate_brand_assets.py
fi

echo "Pillow not found. Choose one:"
echo "  sudo apt install python3-pil     # simplest on Ubuntu"
echo "  or this script will use scripts/.venv automatically."
echo

VENV="$ROOT/scripts/.venv"
if [[ ! -d "$VENV" ]]; then
  if ! python3 -m venv "$VENV" 2>/dev/null; then
    echo "Create a venv failed. Run:"
    echo "  sudo apt install python3-venv python3-pil"
    echo "  python3 scripts/generate_brand_assets.py"
    exit 1
  fi
  "$VENV/bin/pip" install -r scripts/requirements.txt
fi

exec "$VENV/bin/python" scripts/generate_brand_assets.py
