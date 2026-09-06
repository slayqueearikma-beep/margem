#!/usr/bin/env python3
"""Replace old brand text with Dribex in user-facing files only."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Globs / paths to process (user-facing legal, admin UI, docs, emails)
TARGETS: list[Path] = []

for pattern in (
    "legal/**/*.md",
    "souq-local/backend/static/legal/**/*.html",
    "souq-local/backend/static/legal/*.html",
    "souq-local/docs/*.md",
    "souq-local/mobile/PRIVACY_POLICY.md",
    "souq-local/admin-dashboard/index.html",
    "souq-local/admin-dashboard/docker-entrypoint.sh",
    "souq-local/HOME_SERVER.md",
):
    TARGETS.extend(ROOT.glob(pattern))

TARGETS.extend(
    [
        ROOT / "souq-local/backend/scripts/generate_legal_html.py",
        ROOT / "souq-local/backend/app/routers/auth.py",
        ROOT / "souq-local/backend/app/services/signup_verification.py",
        ROOT / "souq-local/backend/app/routers/seller_ops.py",
        ROOT / "souq-local/backend/app/services/community_chat.py",
        ROOT / "souq-local/backend/app/services/geography.py",
        ROOT / "souq-local/backend/app/services/stripe_billing.py",
        ROOT / "souq-local/backend/app/main.py",
        ROOT / "souq-local/backend/app/config.py",
        ROOT / "souq-local/backend/tests/conftest.py",
        ROOT / "souq-local/backend/scripts/entrypoint.sh",
        ROOT / "souq-local/backend/scripts/validate_home_env.py",
        ROOT / "souq-local/start_home_server.sh",
        ROOT / "souq-local/start_home_server.ps1",
        ROOT / "souq-local/stop_home_server.sh",
        ROOT / "souq-local/mobile/lib/core/widgets/legal_links_section.dart",
        ROOT / "souq-local/mobile/lib/features/premium/premium_screen.dart",
        ROOT / "docs/LEGAL_ARABIC_AUDIT_REPORT.md",
    ]
)

SKIP_SUBSTRINGS = (
    "margem://",
    "MARGEM_API_URL",
    "margem_admin_token",
    "margem_logo",
    "margemMember",
    "MarGemApp",
    "MarGemAppBar",
    "margem_navigation",
    "margem_background",
    "margem_home_",
    "margem-prod",
    "margemadmin",
    "margem-media",
    "margem.billing",
    "margem.config",
    "margem.email",
    "margem.security",
    "margem.signup_otp",
    "margem.errors",
    "com.margem.app",
    "jwt_issuer",
    "jwt_audience",
    "margem-api",
    "margem-mobile",
)


def transform_line(line: str) -> str:
    if any(skip in line for skip in SKIP_SUBSTRINGS):
        return line
    text = line
    text = text.replace("MarGem Plus", "Dribex Plus")
    text = text.replace("MarGé", "Dribex")
    text = text.replace("MarGem", "Dribex")
    text = text.replace("MARGE", "DRIBEX")
    text = re.sub(r"@margem\.", "@dribex.", text)
    text = text.replace("margem.ma", "dribex.ma")
    text = text.replace("margem.app", "dribex.app")
    text = text.replace("margem.local", "dribex.local")
    return text


def process_file(path: Path) -> bool:
    if not path.is_file():
        return False
    original = path.read_text(encoding="utf-8")
    updated = "\n".join(transform_line(line) for line in original.splitlines())
    if original.endswith("\n") and not updated.endswith("\n"):
        updated += "\n"
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = 0
    seen: set[Path] = set()
    for path in TARGETS:
        if path in seen:
            continue
        seen.add(path)
        if process_file(path):
            changed += 1
            print(f"updated {path.relative_to(ROOT)}")
    print(f"done: {changed} files")


if __name__ == "__main__":
    main()
