#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/web"

if [[ ! -d node_modules/next ]]; then
  echo "Installing web dependencies (first run)..."
  npm install
fi

if [[ ! -f .env.local ]] && [[ -f env.example ]]; then
  cp env.example .env.local
  echo "Created web/.env.local from env.example"
fi

exec npm run dev
