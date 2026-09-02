#!/usr/bin/env bash
# Install defense-in-depth DOCKER-USER rules for Dribex production.
#
# Policy (evaluated top to bottom):
#   1. Allow established/related
#   2. Allow all traffic arriving on tailscale0 (SSH tunnels, admin, optional API)
#   3. Allow loopback
#   4. Allow TCP destination ports 80 and 443 (nginx)
#   5. DROP everything else forwarded to Docker containers
#
# SAFETY: keep your current SSH session open. Test a second Tailscale SSH
# session before closing this one.
#
# Rollback: ./rollback-docker-user.sh
set -euo pipefail

COMMENT_TAG="dribex-docker-hardening"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/margem/firewall-$(date +%Y%m%d-%H%M%S)}"
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Re-run with sudo: sudo $0" >&2
    exit 1
  fi
}

detect_tailscale_iface() {
  if ip link show tailscale0 &>/dev/null; then
    echo "tailscale0"
    return
  fi
  echo "WARNING: tailscale0 not found — Tailscale bypass rule will be skipped" >&2
  echo ""
}

backup_state() {
  mkdir -p "$BACKUP_DIR"
  echo "Backing up to $BACKUP_DIR"
  iptables-save >"$BACKUP_DIR/iptables-save.txt" 2>/dev/null || true
  ip6tables-save >"$BACKUP_DIR/ip6tables-save.txt" 2>/dev/null || true
  ufw status verbose >"$BACKUP_DIR/ufw-status.txt" 2>/dev/null || true
  docker ps --format 'table {{.Names}}\t{{.Ports}}' >"$BACKUP_DIR/docker-ps.txt" 2>/dev/null || true
  ss -lntup >"$BACKUP_DIR/ss-listeners.txt" 2>/dev/null || true
  cp -a "${COMPOSE_ROOT:-/root}/MarGem/souq-local/infra/onprem/docker-compose.prod.yml" \
    "$BACKUP_DIR/" 2>/dev/null || true
  echo "$BACKUP_DIR" > /var/backups/margem/.last-docker-user-backup 2>/dev/null || true
}

remove_our_rules() {
  local chain="DOCKER-USER"
  while iptables -L "$chain" -n --line-numbers 2>/dev/null | rg -q "$COMMENT_TAG"; do
    local line
    line="$(iptables -L "$chain" -n --line-numbers | rg "$COMMENT_TAG" | head -1 | awk '{print $1}')"
    run iptables -D "$chain" "$line"
  done
}

ensure_chain() {
  if ! iptables -L DOCKER-USER -n &>/dev/null; then
    echo "DOCKER-USER chain missing — is Docker running?" >&2
    exit 1
  fi
}

install_rules() {
  local ts_iface="$1"
  remove_our_rules

  # RETURN rules at top (insert in reverse desired order)
  run iptables -I DOCKER-USER -m comment --comment "$COMMENT_TAG: established" \
    -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN

  if [[ -n "$ts_iface" ]]; then
    run iptables -I DOCKER-USER -m comment --comment "$COMMENT_TAG: tailscale" \
      -i "$ts_iface" -j RETURN
  fi

  run iptables -I DOCKER-USER -m comment --comment "$COMMENT_TAG: loopback" \
    -i lo -j RETURN

  run iptables -I DOCKER-USER -m comment --comment "$COMMENT_TAG: http" \
    -p tcp -m tcp --dport 80 -j RETURN

  run iptables -I DOCKER-USER -m comment --comment "$COMMENT_TAG: https" \
    -p tcp -m tcp --dport 443 -j RETURN

  run iptables -A DOCKER-USER -m comment --comment "$COMMENT_TAG: drop-other" -j DROP
}

persist_rules() {
  if command -v netfilter-persistent >/dev/null; then
    echo "Saving via netfilter-persistent..."
    run netfilter-persistent save
  elif [[ -d /etc/iptables ]]; then
    run iptables-save > /etc/iptables/rules.v4
    echo "Saved to /etc/iptables/rules.v4"
  else
    echo "NOTE: install persistence: sudo apt install iptables-persistent"
    echo "      Then: sudo netfilter-persistent save"
  fi
}

main() {
  require_root
  local ts_iface
  ts_iface="$(detect_tailscale_iface)"
  backup_state
  ensure_chain
  install_rules "$ts_iface"

  echo ""
  echo "=== DOCKER-USER after install ==="
  iptables -L DOCKER-USER -n -v --line-numbers

  if [[ "$DRY_RUN" != "1" && "${SKIP_PERSIST_PROMPT:-0}" != "1" ]]; then
  echo ""
  echo "Verify HTTPS still works:"
  echo "  curl -fsS https://api.dribex.ma/ready"
  echo "  curl -fsI https://dribex.ma"
  echo ""
  echo "Open a SECOND Tailscale SSH session before closing this one."
  read -r -p "Persist rules to disk? [y/N] " ans
  if [[ "${ans,,}" == "y" ]]; then
    persist_rules
  fi
  elif [[ "${PERSIST_RULES:-0}" == "1" ]]; then
    persist_rules
  fi
  fi

  echo "Backup: $BACKUP_DIR"
  echo "Rollback: sudo $(dirname "$0")/rollback-docker-user.sh"
}

main "$@"
