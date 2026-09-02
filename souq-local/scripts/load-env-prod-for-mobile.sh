#!/usr/bin/env bash
# Load production mobile build variables from the environment or infra/onprem/.env.prod.
# Never prints secret values.
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/infra/onprem/.env.prod}"

_read_env_prod_var() {
  local key="$1"
  [[ -f "$ENV_FILE" ]] || return 1
  local line
  line="$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  local value="${line#*=}"
  value="${value%$'\r'}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

if [[ -z "${SENTRY_DSN:-}" ]]; then
  SENTRY_DSN="$(_read_env_prod_var SENTRY_DSN || true)"
  export SENTRY_DSN
fi

if [[ -z "${API_BASE_URL:-}" ]]; then
  API_BASE_URL="$(_read_env_prod_var PUBLIC_API_URL || true)"
  API_BASE_URL="${API_BASE_URL:-https://api.dribex.ma}"
  export API_BASE_URL
fi
