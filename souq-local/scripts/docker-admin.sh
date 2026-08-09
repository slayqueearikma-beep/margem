#!/usr/bin/env bash
# MarGem Docker helpers — start stack, promote admin, list users.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose)
DB_USER="souq"
DB_NAME="souq_local"

usage() {
  cat <<'EOF'
MarGem Docker admin helpers

Usage:
  ./scripts/docker-admin.sh up              Start API + Postgres (build if needed)
  ./scripts/docker-admin.sh down            Stop containers
  ./scripts/docker-admin.sh logs            Follow API logs
  ./scripts/docker-admin.sh psql            Open Postgres shell
  ./scripts/docker-admin.sh list-users      List all accounts in the database
  ./scripts/docker-admin.sh promote-admin <email>   Grant admin role to a user

After `up`:
  API docs   http://localhost:8000/docs
  Admin UI   http://localhost:8000/admin

Register a user in the mobile app first, then:
  ./scripts/docker-admin.sh promote-admin you@example.com
EOF
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  up)
    "${COMPOSE[@]}" up -d --build
    echo ""
    echo "MarGem is running."
    echo "  Admin dashboard: http://localhost:8000/admin"
    echo "  API docs:        http://localhost:8000/docs"
    echo ""
    echo "Register in the app, then promote your account:"
    echo "  ./scripts/docker-admin.sh promote-admin your@email.com"
    ;;
  down)
    "${COMPOSE[@]}" down
    ;;
  logs)
    "${COMPOSE[@]}" logs -f api
    ;;
  psql)
    "${COMPOSE[@]}" exec postgres psql -U "$DB_USER" -d "$DB_NAME"
    ;;
  list-users)
    "${COMPOSE[@]}" exec postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
      "SELECT email, role, status, account_type, created_at FROM users ORDER BY created_at DESC;"
    ;;
  promote-admin)
    email="${1:-}"
    if [[ -z "$email" ]]; then
      echo "Usage: $0 promote-admin <email>" >&2
      exit 1
    fi
    "${COMPOSE[@]}" exec postgres psql -U "$DB_USER" -d "$DB_NAME" -c \
      "UPDATE users SET role = 'admin' WHERE lower(email) = lower('${email//\'/''}');"
    echo "Promoted ${email} to admin (if the account exists)."
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
