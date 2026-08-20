#!/usr/bin/env bash
# Diagnose margem-home-api startup failures on the home server.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.home}"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"
API_CONTAINER="${API_CONTAINER:-margem-home-api}"
API_PORT="$(grep -E '^API_PORT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
API_PORT="${API_PORT:-8000}"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

section() {
  echo ""
  echo "=== $* ==="
}

if [[ ! -f "$ENV_FILE" ]]; then
  red "Missing $ENV_FILE — copy env.home.example to .env.home first."
  exit 1
fi

section "Environment validation"
if PYTHONPATH="$ROOT/backend" python3 "$ROOT/backend/scripts/validate_home_env.py" "$ENV_FILE"; then
  green "validate_home_env.py: OK"
else
  red "Fix .env.home errors above, then rebuild."
fi

section "Container status"
docker ps -a --filter "name=${API_CONTAINER}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
if docker inspect "$API_CONTAINER" >/dev/null 2>&1; then
  health="$(docker inspect "$API_CONTAINER" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || true)"
  exit_code="$(docker inspect "$API_CONTAINER" --format '{{.State.ExitCode}}' 2>/dev/null || true)"
  echo "Health: ${health:-unknown}  Last exit code: ${exit_code:-unknown}"
  if [[ "${health:-}" == "unhealthy" ]]; then
    yellow "Container is running but failing Docker healthcheck (/ready must return 200)."
  fi
  if [[ "${exit_code:-0}" != "0" ]]; then
    yellow "Container exited — see logs below for the crash reason."
  fi
else
  yellow "Container ${API_CONTAINER} not found."
fi

section "Last 80 lines of API logs"
docker logs "$API_CONTAINER" --tail 80 2>&1 || yellow "No logs available."

section "HTTP probes (from host)"
probe() {
  local label="$1"
  local url="$2"
  local extra_args="${3:-}"
  # shellcheck disable=SC2086
  if out="$(curl -fsS $extra_args "$url" 2>&1)"; then
    green "$label -> OK"
    echo "$out" | head -c 400
    echo ""
  else
    red "$label -> FAILED"
    echo "$out"
  fi
}

probe "GET /health" "http://127.0.0.1:${API_PORT}/health"
probe "GET /ready" "http://127.0.0.1:${API_PORT}/ready"
probe "GET /live" "http://127.0.0.1:${API_PORT}/live"

section "Common fixes"
cat <<EOF
1. Migration error (Can't locate revision / alembic failed):
   git pull origin cursor/final-integration-ee43
   docker compose -f docker-compose.home.yml --env-file .env.home up -d --build api

2. Settings validation (MFA/JWT secrets, APP_ENV=production):
   APP_ENV=development in .env.home
   Three different secrets: JWT_SECRET_KEY, UPLOAD_TOKEN_SECRET, MFA_ENCRYPTION_KEY
   python3 backend/scripts/validate_home_env.py .env.home

3. Media directory not writable:
   docker run --rm --user root -v souq-local_margem_home_media:/data alpine \\
     sh -c "chown -R 999:999 /data && chmod -R u+rwX /data"

4. /health OK but /ready fails (schema or media):
   docker compose -f docker-compose.home.yml --env-file .env.home logs api | tail -50
   docker compose -f docker-compose.home.yml --env-file .env.home exec api alembic current

5. Start API without waiting for admin (debug):
   docker compose -f docker-compose.home.yml --env-file .env.home up -d --no-deps api
EOF
