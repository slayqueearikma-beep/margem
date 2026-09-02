#!/usr/bin/env bash
# Roll back Dribex DOCKER-USER hardening rules.
# Restores iptables from the most recent backup when available.
set -euo pipefail

COMMENT_TAG="dribex-docker-hardening"
BACKUP_HINT="/var/backups/margem/.last-docker-user-backup"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Re-run with sudo: sudo $0" >&2
  exit 1
fi

echo "Removing $COMMENT_TAG rules from DOCKER-USER..."
while iptables -L DOCKER-USER -n --line-numbers 2>/dev/null | rg -q "$COMMENT_TAG"; do
  line="$(iptables -L DOCKER-USER -n --line-numbers | rg "$COMMENT_TAG" | head -1 | awk '{print $1}')"
  iptables -D DOCKER-USER "$line"
done

if [[ -f "$BACKUP_HINT" ]]; then
  BACKUP_DIR="$(cat "$BACKUP_HINT")"
  if [[ -f "$BACKUP_DIR/iptables-save.txt" ]]; then
    read -r -p "Also restore full iptables from $BACKUP_DIR? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
      iptables-restore <"$BACKUP_DIR/iptables-save.txt"
      echo "Restored iptables from backup."
    fi
  fi
fi

echo "=== DOCKER-USER after rollback ==="
iptables -L DOCKER-USER -n -v --line-numbers || true
echo "Done."
