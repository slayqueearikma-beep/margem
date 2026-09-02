#!/usr/bin/env bash
# Roll back Dribex DOCKER-USER hardening rules.
# Restores iptables from the most recent backup when requested.
set -euo pipefail

COMMENT_TAG="dribex-docker-hardening"
BACKUP_HINT="/var/backups/margem/.last-docker-user-backup"
CONFIRM="${CONFIRM:-0}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Re-run with sudo: sudo $0" >&2
  exit 1
fi

if [[ "$CONFIRM" != "1" ]]; then
  echo "This removes dribex DOCKER-USER hardening rules." >&2
  echo "Run: sudo CONFIRM=1 $0" >&2
  exit 1
fi

echo "Removing $COMMENT_TAG rules from DOCKER-USER..."
while iptables -L DOCKER-USER -n --line-numbers 2>/dev/null | grep -q "$COMMENT_TAG"; do
  line="$(iptables -L DOCKER-USER -n --line-numbers | grep "$COMMENT_TAG" | head -1 | awk '{print $1}')"
  [[ -n "$line" ]] || break
  iptables -D DOCKER-USER "$line"
done

if [[ -f "$BACKUP_HINT" ]]; then
  BACKUP_DIR="$(cat "$BACKUP_HINT")"
  if [[ -f "$BACKUP_DIR/iptables-save.txt" ]]; then
    echo "Full iptables backup available: $BACKUP_DIR/iptables-save.txt"
    echo "To restore everything: sudo iptables-restore < $BACKUP_DIR/iptables-save.txt"
  fi
fi

echo "=== DOCKER-USER after rollback ==="
iptables -L DOCKER-USER -n -v --line-numbers || true
echo "Done."
