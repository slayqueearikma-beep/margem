#!/usr/bin/env bash
# Install defense-in-depth DOCKER-USER rules for Dribex production.
#
# Policy (first match wins, top to bottom):
#   1. Allow established/related
#   2. Allow all traffic arriving on tailscale0 (SSH, admin, optional API)
#   3. Allow loopback
#   4. Allow TCP destination ports 80 and 443 (nginx / public web)
#   5. Optional extra ports via ALLOW_EXTRA_PORTS (comma-separated, lab only)
#   6. DROP everything else forwarded to Docker containers
#
# SAFETY:
#   - Run audit first: ./audit-docker-exposure.sh
#   - Preview:        sudo DRY_RUN=1 ./harden-docker-user.sh
#   - Apply:          sudo CONFIRM=1 ./harden-docker-user.sh
#   - Keep your current SSH session open; test a second Tailscale session first.
#   - Rollback:       sudo ./rollback-docker-user.sh
#
# Does NOT persist rules unless PERSIST_RULES=1 (never prompts interactively).
set -euo pipefail

COMMENT_TAG="dribex-docker-hardening"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_ROOT="${COMPOSE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/margem/firewall-$(date +%Y%m%d-%H%M%S)}"
DRY_RUN="${DRY_RUN:-0}"
CONFIRM="${CONFIRM:-0}"
PERSIST_RULES="${PERSIST_RULES:-0}"
ALLOW_EXTRA_PORTS="${ALLOW_EXTRA_PORTS:-}"

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

has_chain_rules() {
  local chain="$1"
  iptables -L "$chain" -n 2>/dev/null | grep -q "$COMMENT_TAG"
}

detect_tailscale_iface() {
  if ip link show tailscale0 &>/dev/null; then
    echo "tailscale0"
    return
  fi
  echo "WARNING: tailscale0 not found — Tailscale bypass rule will be skipped" >&2
  echo "         SSH/admin over Tailscale will NOT work through Docker publishes." >&2
  echo ""
}

audit_published_ports() {
  local bad=0
  local line
  echo "=== Preflight: Docker published ports ==="
  if ! command -v docker >/dev/null; then
    echo "WARNING: docker not found — skipping port audit" >&2
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Examples:
    #   0.0.0.0:8000->8000/tcp
    #   100.64.0.1:8000->8000/tcp  (Tailscale — OK)
    #   0.0.0.0:80->80/tcp          (nginx — OK)
    if echo "$line" | grep -qE '0\.0\.0\.0:[0-9]+->|:::?[0-9]+->|\[::\]:'; then
      if echo "$line" | grep -qE '->80/tcp|->443/tcp'; then
        echo "  OK   $line"
      else
        echo "  RISK $line  (public bind — not 80/443)" >&2
        bad=1
      fi
    elif echo "$line" | grep -qE '100\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+->'; then
      echo "  OK   $line  (Tailscale bind)"
    elif echo "$line" | grep -qE '127\.0\.0\.1:[0-9]+->'; then
      echo "  OK   $line  (localhost bind)"
    fi
  done < <(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -E ':[0-9]+->' || true)

  if [[ "$bad" -eq 1 ]]; then
    echo "" >&2
    echo "ABORT: Docker is publishing non-web ports on 0.0.0.0." >&2
    echo "Fix compose first (use docker-compose.prod.yml — API must not publish 8000)." >&2
    echo "Re-run audit: $SCRIPT_DIR/audit-docker-exposure.sh" >&2
    echo "If this is intentional for lab, set ALLOW_EXTRA_PORTS=8000,7215 and CONFIRM=1." >&2
    if [[ -z "$ALLOW_EXTRA_PORTS" ]]; then
      exit 1
    fi
    echo "ALLOW_EXTRA_PORTS=$ALLOW_EXTRA_PORTS — continuing because extra ports were declared." >&2
  fi
  echo ""
}

remove_our_rules() {
  local chain="DOCKER-USER"
  while has_chain_rules "$chain"; do
    local line
    line="$(iptables -L "$chain" -n --line-numbers | grep "$COMMENT_TAG" | head -1 | awk '{print $1}')"
    [[ -n "$line" ]] || break
    run iptables -D "$chain" "$line"
  done
}

ensure_chain() {
  if ! iptables -L DOCKER-USER -n &>/dev/null; then
    echo "DOCKER-USER chain missing — is Docker running?" >&2
    exit 1
  fi
}

append_return_rule() {
  local comment="$1"
  shift
  run iptables -A DOCKER-USER -m comment --comment "$COMMENT_TAG: $comment" "$@" -j RETURN
}

install_rules() {
  local ts_iface="$1"
  remove_our_rules

  # Append in priority order (first match wins).
  append_return_rule "established" -m conntrack --ctstate RELATED,ESTABLISHED

  if [[ -n "$ts_iface" ]]; then
    append_return_rule "tailscale" -i "$ts_iface"
  fi

  append_return_rule "loopback" -i lo
  append_return_rule "http" -p tcp -m tcp --dport 80
  append_return_rule "https" -p tcp -m tcp --dport 443

  if [[ -n "$ALLOW_EXTRA_PORTS" ]]; then
    local port
    IFS=',' read -ra _extra <<<"$ALLOW_EXTRA_PORTS"
    for port in "${_extra[@]}"; do
      port="$(echo "$port" | tr -d ' ')"
      [[ -n "$port" ]] || continue
      append_return_rule "extra-$port" -p tcp -m tcp --dport "$port"
    done
  fi

  run iptables -A DOCKER-USER -m comment --comment "$COMMENT_TAG: drop-other" -j DROP
}

backup_state() {
  mkdir -p "$BACKUP_DIR"
  echo "Backing up to $BACKUP_DIR"
  iptables-save >"$BACKUP_DIR/iptables-save.txt" 2>/dev/null || true
  ip6tables-save >"$BACKUP_DIR/ip6tables-save.txt" 2>/dev/null || true
  ufw status verbose >"$BACKUP_DIR/ufw-status.txt" 2>/dev/null || true
  docker ps --format 'table {{.Names}}\t{{.Ports}}' >"$BACKUP_DIR/docker-ps.txt" 2>/dev/null || true
  ss -lntup >"$BACKUP_DIR/ss-listeners.txt" 2>/dev/null || true
  cp -a "$COMPOSE_ROOT/docker-compose.prod.yml" "$BACKUP_DIR/" 2>/dev/null || true
  mkdir -p /var/backups/margem
  echo "$BACKUP_DIR" > /var/backups/margem/.last-docker-user-backup 2>/dev/null || true
}

persist_rules() {
  if command -v netfilter-persistent >/dev/null; then
    echo "Saving via netfilter-persistent..."
    run netfilter-persistent save
  elif [[ -d /etc/iptables ]]; then
    run iptables-save > /etc/iptables/rules.v4
    echo "Saved to /etc/iptables/rules.v4"
  else
    echo "NOTE: rules are active now but will not survive reboot."
    echo "      Install persistence: sudo apt install iptables-persistent"
    echo "      Then: sudo PERSIST_RULES=1 $0"
  fi
}

post_install_checks() {
  echo ""
  echo "=== DOCKER-USER after install ==="
  iptables -L DOCKER-USER -n -v --line-numbers
  echo ""
  echo "Verify (from this host or another network):"
  echo "  curl -fsS https://api.dribex.ma/ready"
  echo "  curl -fsI https://dribex.ma"
  if [[ -n "$(detect_tailscale_iface)" ]]; then
    echo "  tailscale ssh piocco@<pi>   # second session before closing this one"
  fi
  echo ""
  echo "Backup: $BACKUP_DIR"
  echo "Rollback: sudo $SCRIPT_DIR/rollback-docker-user.sh"
}

main() {
  require_root

  if [[ "$CONFIRM" != "1" && "$DRY_RUN" != "1" ]]; then
    echo "Refusing to modify firewall without CONFIRM=1." >&2
    echo "" >&2
    echo "Steps:" >&2
    echo "  1. $SCRIPT_DIR/audit-docker-exposure.sh" >&2
    echo "  2. sudo DRY_RUN=1 $0" >&2
    echo "  3. sudo CONFIRM=1 $0" >&2
    echo "" >&2
    echo "Optional lab ports: sudo CONFIRM=1 ALLOW_EXTRA_PORTS=7215 $0" >&2
    echo "Persist after reboot: sudo CONFIRM=1 PERSIST_RULES=1 $0" >&2
    exit 1
  fi

  local ts_iface
  ts_iface="$(detect_tailscale_iface)"
  audit_published_ports
  backup_state
  ensure_chain
  install_rules "$ts_iface"
  post_install_checks

  if [[ "$DRY_RUN" != "1" && "$PERSIST_RULES" == "1" ]]; then
    persist_rules
  elif [[ "$DRY_RUN" != "1" ]]; then
    echo ""
    echo "Rules applied in memory only (reboot may clear them)."
    echo "After verifying HTTPS works: sudo CONFIRM=1 PERSIST_RULES=1 $0"
  fi
}

main "$@"
