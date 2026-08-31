#!/usr/bin/env bash
# Validate production environment file before deploy.
# Never prints secret values — only variable names and pass/fail status.
set -euo pipefail

ENV_FILE="${1:-}"
if [[ -z "$ENV_FILE" || ! -f "$ENV_FILE" ]]; then
  echo "Usage: $0 /path/to/.env.prod" >&2
  exit 1
fi

declare -A raw=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  if [[ "$line" == *=* ]]; then
    key="${line%%=*}"
    value="${line#*=}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    raw["$key"]="$value"
  fi
done < "$ENV_FILE"

errors=()
warnings=()

get() {
  echo "${raw[$1]:-}"
}

is_placeholder() {
  local value="$1"
  [[ -z "$value" ]] && return 0
  shopt -s nocasematch
  [[ "$value" == *"CHANGE_ME"* ]] && return 0
  [[ "$value" == *"<generate"* ]] && return 0
  [[ "$value" == "YOUR_OFFICE_OR_VPN_CIDR" ]] && return 0
  shopt -u nocasematch
  return 1
}

require_nonempty() {
  local key="$1"
  local value
  value="$(get "$key")"
  if [[ -z "$value" ]]; then
    errors+=("$key is required but empty")
    return
  fi
  if is_placeholder "$value"; then
    errors+=("$key still contains a placeholder value")
  fi
}

require_min_len() {
  local key="$1"
  local min="$2"
  local value
  value="$(get "$key")"
  if [[ ${#value} -lt $min ]]; then
    errors+=("$key must be at least $min characters")
  fi
}

require_distinct() {
  local a="$1"
  local b="$2"
  local va vb
  va="$(get "$a")"
  vb="$(get "$b")"
  if [[ -n "$va" && "$va" == "$vb" ]]; then
    errors+=("$a must differ from $b")
  fi
}

# Core secrets
for key in JWT_SECRET_KEY UPLOAD_TOKEN_SECRET MFA_ENCRYPTION_KEY POSTGRES_PASSWORD MINIO_ROOT_PASSWORD; do
  require_nonempty "$key"
done
require_min_len JWT_SECRET_KEY 32
require_min_len UPLOAD_TOKEN_SECRET 32
require_min_len MFA_ENCRYPTION_KEY 32
require_distinct JWT_SECRET_KEY UPLOAD_TOKEN_SECRET
require_distinct JWT_SECRET_KEY MFA_ENCRYPTION_KEY
require_distinct UPLOAD_TOKEN_SECRET MFA_ENCRYPTION_KEY

# Email (required unless explicit break-glass)
brevo_key="$(get BREVO_API_KEY)"
insecure_fallback="$(get ALLOW_INSECURE_EMAIL_FALLBACK)"
if [[ "${insecure_fallback,,}" == "true" ]]; then
  warnings+=("ALLOW_INSECURE_EMAIL_FALLBACK=true — emails will be logged only, not delivered")
  if [[ -z "$brevo_key" ]]; then
    warnings+=("BREVO_API_KEY is empty — acceptable only with break-glass fallback enabled")
  fi
else
  require_nonempty BREVO_API_KEY
  require_nonempty BREVO_SENDER_EMAIL
  require_nonempty BREVO_SENDER_NAME
fi

# Rewarded ads signing secret
if [[ "$(get REWARDED_ADS_ENABLED)" == "true" ]]; then
  require_nonempty REWARDED_AD_SIGNING_SECRET
  require_min_len REWARDED_AD_SIGNING_SECRET 32
fi

# Admin network guard
require_nonempty ADMIN_IP_ALLOWLIST
if [[ "$(get ADMIN_REQUIRE_STAFF_MFA)" != "true" ]]; then
  errors+=("ADMIN_REQUIRE_STAFF_MFA must be true in production")
fi

# Public URLs
for key in PUBLIC_API_URL PUBLIC_APP_URL; do
  require_nonempty "$key"
  value="$(get "$key")"
  if [[ "$value" == http://* ]]; then
    errors+=("$key must use HTTPS in production")
  fi
  if echo "$value" | rg -qi 'localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.|100\.80\.'; then
    errors+=("$key must not contain development-only hosts")
  fi
  if echo "$value" | rg -qi 'margem\.ma'; then
    errors+=("$key must use dribex.ma production domains")
  fi
done

# Open beta monetization lock — payments are out of scope.
payments="$(get PAYMENTS_ENABLED)"
subs="$(get SUBSCRIPTIONS_ENABLED)"
payment_provider="$(get PAYMENT_PROVIDER)"
if [[ "${payments,,}" == "true" ]]; then
  errors+=("PAYMENTS_ENABLED must be false for open public beta")
fi
if [[ "${subs,,}" == "true" ]]; then
  errors+=("SUBSCRIPTIONS_ENABLED must be false for open public beta")
fi
if [[ -n "$payment_provider" && "${payment_provider,,}" != "none" ]]; then
  errors+=("PAYMENT_PROVIDER must be 'none' for open public beta")
fi
if [[ "$(get ADS_ENABLED)" != "true" ]]; then
  warnings+=("ADS_ENABLED is not true — manual advertising will be disabled")
fi

# Hosts / CORS
require_nonempty ALLOWED_HOSTS
require_nonempty CORS_ORIGINS
if echo "$(get CORS_ORIGINS)" | rg -q '\*'; then
  errors+=("CORS_ORIGINS must not use wildcard '*' in production")
fi
for key in CORS_ORIGINS ALLOWED_HOSTS; do
  value="$(get "$key")"
  if echo "$value" | rg -qi 'localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.|100\.80\.'; then
    errors+=("$key must not contain development-only hosts")
  fi
done

minio_user="$(get MINIO_ROOT_USER)"
minio_pass="$(get MINIO_ROOT_PASSWORD)"
if [[ -n "$minio_user" ]] && is_placeholder "$minio_user"; then
  errors+=("MINIO_ROOT_USER still contains a placeholder value")
fi
if [[ -n "$minio_pass" ]] && is_placeholder "$minio_pass"; then
  errors+=("MINIO_ROOT_PASSWORD still contains a placeholder value")
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "Production environment validation FAILED:" >&2
  for item in "${errors[@]}"; do
    echo "  - $item" >&2
  done
  exit 1
fi

echo "Production environment validation passed."
if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "Warnings:"
  for item in "${warnings[@]}"; do
    echo "  - $item"
  done
fi
