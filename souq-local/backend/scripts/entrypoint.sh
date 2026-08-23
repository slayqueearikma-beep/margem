#!/bin/sh
set -e

echo "Waiting for database..."
python - <<'PY'
import asyncio
import os
import sys
import time

url = os.environ.get("DATABASE_URL", "")
if not url:
    print("DATABASE_URL is not set", file=sys.stderr)
    sys.exit(1)

async def wait_for_db(timeout_s: int = 60) -> None:
    from sqlalchemy.ext.asyncio import create_async_engine
    from sqlalchemy import text

    engine = create_async_engine(url, pool_pre_ping=True)
    deadline = time.time() + timeout_s
    last_err = None
    while time.time() < deadline:
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            await engine.dispose()
            print("Database is ready.")
            return
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(2)
    await engine.dispose()
    print(f"Database not ready: {last_err}", file=sys.stderr)
    sys.exit(1)

asyncio.run(wait_for_db())
PY

echo "Running database migrations..."
alembic upgrade head

if [ "${STORAGE_BACKEND:-local}" = "local" ]; then
  MEDIA_DIR="${LOCAL_MEDIA_ROOT:-/data/media}"
  if ! python - <<'PY'
import os
import sys
root = os.environ.get("LOCAL_MEDIA_ROOT", "/data/media")
try:
    os.makedirs(root, exist_ok=True)
    probe = os.path.join(root, ".writable_probe")
    with open(probe, "w", encoding="utf-8") as fh:
        fh.write("ok")
    os.remove(probe)
except OSError as exc:
    print(f"Media directory not writable: {root} ({exc})", file=sys.stderr)
    sys.exit(1)
print(f"Media directory OK: {root}")
PY
  then
    echo "Local media storage is not writable — check volume permissions." >&2
    exit 1
  fi
fi

echo "Starting MarGem API..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
