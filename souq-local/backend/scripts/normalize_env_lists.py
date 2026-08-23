#!/usr/bin/env python3
"""Normalize list-like env vars before pydantic-settings loads Settings.

Accepts comma-separated values or JSON arrays (including broken JSON missing
quotes). Rewrites the env var to a valid JSON array string so both old and new
pydantic-settings versions can parse list fields reliably.
"""
from __future__ import annotations

import json
import os
import sys


def parse_to_list(raw: str) -> list[str]:
    value = raw.strip().strip("'").strip('"')
    if not value:
        return []
    if value.startswith("["):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        except json.JSONDecodeError:
            inner = value.strip("[]")
            return [
                item.strip().strip('"').strip("'")
                for item in inner.split(",")
                if item.strip()
            ]
    return [
        item.strip().strip('"').strip("'")
        for item in value.split(",")
        if item.strip()
    ]


def main() -> int:
    keys = ("CORS_ORIGINS", "ALLOWED_HOSTS", "UPLOAD_ALLOWED_HOSTS")
    changed = False
    for key in keys:
        raw = os.environ.get(key, "")
        if not raw:
            continue
        items = parse_to_list(raw)
        normalized = json.dumps(items)
        if normalized != raw:
            os.environ[key] = normalized
            changed = True
            print(f"Normalized {key}={normalized}", file=sys.stderr)
    return 0 if changed or True else 1


if __name__ == "__main__":
    raise SystemExit(main())
