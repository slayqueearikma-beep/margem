#!/usr/bin/env bash
# Sync Postgres margemadmin password with POSTGRES_PASSWORD in .env.home.
#
# Postgres only reads POSTGRES_PASSWORD when the data volume is first created.
# If you change .env.home later, the API fails with:
#   password authentication failed for user "margemadmin"
#
# This script updates the DB user password without wiping data.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env.home}"
DB_CONTAINER="${DB_CONTAINER:-margem-home-db}"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | tail -n1 | cut -d= -f2- | sed 's/^["'\'']//;s/["'\'']$//')"
if [[ -z "$POSTGRES_PASSWORD" ]]; then
  echo "POSTGRES_PASSWORD is empty in $ENV_FILE" >&2
  exit 1
fi

if ! docker inspect "$DB_CONTAINER" >/dev/null 2>&1; then
  echo "Database container $DB_CONTAINER not found. Start Postgres first:" >&2
  echo "  docker compose -f $COMPOSE_FILE --env-file $ENV_FILE up -d postgres" >&2
  exit 1
fi

# Escape single quotes for SQL string literal.
sql_password="${POSTGRES_PASSWORD//\'/\'\'}"

echo "Updating margemadmin password to match $ENV_FILE ..."
docker exec "$DB_CONTAINER" psql -U margemadmin -d margem -v ON_ERROR_STOP=1 \
  -c "ALTER USER margemadmin WITH PASSWORD '${sql_password}';"

echo "Verifying password over TCP (same path the API uses) ..."
if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
  psql -h 127.0.0.1 -U margemadmin -d margem -v ON_ERROR_STOP=1 -c "SELECT 1" >/dev/null; then
  echo "OK — database password matches .env.home"
else
  echo "Password update did not verify — check logs above." >&2
  exit 1
fi

echo ""
echo "Restart the API:"
echo "  docker compose -f docker-compose.home.yml --env-file .env.home up -d api"
