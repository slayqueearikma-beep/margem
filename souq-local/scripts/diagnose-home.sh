#!/usr/bin/env bash
# Quick diagnostics when margem-home-api fails to start.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f docker-compose.home.yml --env-file .env.home)
ENV_FILE="$ROOT/.env.home"

echo "=== MarGem home server diagnostics ==="
echo ""

if [[ ! -f "$ENV_FILE" ]]; then
  echo "MISSING: .env.home"
  echo "  cp env.home.example .env.home"
  echo "  Edit passwords and your LAN IP, then re-run compose."
  exit 1
fi

echo "--- .env.home (required keys) ---"
for key in POSTGRES_PASSWORD JWT_SECRET_KEY UPLOAD_TOKEN_SECRET PUBLIC_API_URL ALLOWED_HOSTS CORS_ORIGINS; do
  if grep -qE "^${key}=.+" "$ENV_FILE"; then
    echo "  OK  $key"
  else
    echo "  !!  $key is missing or empty"
  fi
done

jwt_len="$(grep -E '^JWT_SECRET_KEY=' "$ENV_FILE" | tail -n1 | cut -d= -f2- | wc -c)"
if [[ "${jwt_len:-0}" -lt 33 ]]; then
  echo "  !!  JWT_SECRET_KEY must be at least 32 characters"
fi

echo ""
echo "--- Container status ---"
"${COMPOSE[@]}" ps -a 2>/dev/null || docker compose -f docker-compose.home.yml ps -a

echo ""
echo "--- API logs (last 80 lines) ---"
"${COMPOSE[@]}" logs --tail=80 api 2>/dev/null || true

echo ""
echo "--- Common fixes ---"
cat <<'EOF'
1. SMTP not configured → set in .env.home:
     ALLOW_INSECURE_EMAIL_FALLBACK=true

2. Weak secrets → use 32+ random chars for JWT_SECRET_KEY and UPLOAD_TOKEN_SECRET
   (they must be different values).

3. Port in use → change API_PORT in .env.home or stop the other service.

4. After editing .env.home:
     docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
EOF
