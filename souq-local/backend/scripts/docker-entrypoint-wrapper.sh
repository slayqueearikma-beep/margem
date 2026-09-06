#!/bin/sh
# Runs as root so named Docker volumes can be chowned for the margem app user.
set -e

MEDIA_DIR="${LOCAL_MEDIA_ROOT:-/data/media}"
if [ "${STORAGE_PROVIDER:-}" = "local" ] || [ "${STORAGE_BACKEND:-}" = "local" ]; then
  mkdir -p "$MEDIA_DIR"
  chown -R margem:margem "$MEDIA_DIR" 2>/dev/null || true
  chmod -R u+rwX "$MEDIA_DIR" 2>/dev/null || true
fi

exec gosu margem /app/scripts/entrypoint.sh "$@"
