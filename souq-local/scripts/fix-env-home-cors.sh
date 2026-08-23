#!/usr/bin/env bash
# Rewrite CORS_ORIGINS / ALLOWED_HOSTS in .env.home to comma-separated (no brackets).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT/.env.home}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

python3 - "$ENV_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text().splitlines()
keys = {"CORS_ORIGINS", "ALLOWED_HOSTS", "UPLOAD_ALLOWED_HOSTS"}

def parse(raw: str) -> list[str]:
    raw = raw.strip().strip("'").strip('"')
    if not raw:
        return []
    if raw.startswith("["):
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [str(x).strip() for x in data if str(x).strip()]
        except json.JSONDecodeError:
            inner = raw.strip("[]")
            return [p.strip().strip('"').strip("'") for p in inner.split(",") if p.strip()]
    return [p.strip().strip('"').strip("'") for p in raw.split(",") if p.strip()]

out = []
for line in lines:
    matched = False
    for key in keys:
        if line.startswith(f"{key}="):
            value = line.split("=", 1)[1]
            fixed = ",".join(parse(value))
            out.append(f"{key}={fixed}")
            print(f"Fixed {key}={fixed}")
            matched = True
            break
    if not matched:
        out.append(line)

path.write_text("\n".join(out) + "\n")
PY

echo ""
echo "Done. Restart with:"
echo "  docker compose -f docker-compose.home.yml --env-file .env.home up -d --build"
