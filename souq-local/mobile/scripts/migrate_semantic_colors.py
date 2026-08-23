#!/usr/bin/env python3
"""Migrate AppColors.* references to context.colors.* semantic tokens."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"

EXCLUDE = {
    "features/splash/splash_screen.dart",
    "core/widgets/onboarding_backdrop.dart",
    "core/widgets/margem_m_logo.dart",
    "core/widgets/app_brand_logo.dart",
    "core/theme/app_colors.dart",
    "core/theme/app_semantic_colors.dart",
    "core/theme/app_theme.dart",
    "core/theme/theme_context.dart",
}

REPLACEMENTS = [
    ("AppColors.lavenderMuted", "context.colors.primaryMuted"),
    ("AppColors.primaryMuted", "context.colors.primaryMuted"),
    ("AppColors.lavenderLight", "context.colors.primary"),
    ("AppColors.lavenderDark", "context.colors.primary"),
    ("AppColors.lavenderShadow", "context.colors.primary"),
    ("AppColors.lavenderSurface", "context.colors.primaryMuted"),
    ("AppColors.lavender", "context.colors.primary"),
    ("AppColors.primaryLight", "context.colors.primary"),
    ("AppColors.primaryDark", "context.colors.primary"),
    ("AppColors.primary", "context.colors.primary"),
    ("AppColors.beigeLight", "context.colors.surfaceVariant"),
    ("AppColors.surfaceMuted", "context.colors.surfaceVariant"),
    ("AppColors.creamSoft", "context.colors.background"),
    ("AppColors.ultraLight", "context.colors.background"),
    ("AppColors.cream", "context.colors.surface"),
    ("AppColors.surfaceLight", "context.colors.surface"),
    ("AppColors.background", "context.colors.background"),
    ("AppColors.beige", "context.colors.border"),
    ("AppColors.peachLight", "context.colors.surfaceVariant"),
    ("AppColors.peachMuted", "context.colors.surfaceVariant"),
    ("AppColors.peachSurface", "context.colors.surface"),
    ("AppColors.peachDark", "context.colors.secondary"),
    ("AppColors.peach", "context.colors.secondary"),
    ("AppColors.secondaryLight", "context.colors.textTertiary"),
    ("AppColors.secondary", "context.colors.secondary"),
    ("AppColors.navy", "context.colors.textPrimary"),
    ("AppColors.charcoal", "context.colors.textPrimary"),
    ("AppColors.textPrimary", "context.colors.textPrimary"),
    ("AppColors.textSecondary", "context.colors.textSecondary"),
    ("AppColors.textTertiary", "context.colors.textTertiary"),
    ("AppColors.borderLight", "context.colors.divider"),
    ("AppColors.border", "context.colors.border"),
    ("AppColors.cardUnselected", "context.colors.surface"),
    ("AppColors.cardSelected", "context.colors.surfaceVariant"),
    ("AppColors.dangerMuted", "context.colors.errorMuted"),
    ("AppColors.danger", "context.colors.error"),
    ("AppColors.successMuted", "context.colors.successMuted"),
    ("AppColors.success", "context.colors.success"),
    ("AppColors.warningMuted", "context.colors.warningMuted"),
    ("AppColors.warning", "context.colors.warning"),
    ("AppColors.infoMuted", "context.colors.infoMuted"),
    ("AppColors.info", "context.colors.info"),
    ("AppColors.star", "context.colors.star"),
    ("AppColors.goldenCrown", "context.colors.highlight"),
    ("AppColors.customerAccent", "context.colors.primary"),
    ("AppColors.providerAccent", "context.colors.secondary"),
    ("AppColors.darkTextSecondary", "context.colors.textSecondary"),
    ("AppColors.darkPrimaryMuted", "context.colors.primaryMuted"),
    ("AppColors.darkPrimary", "context.colors.primary"),
    ("AppColors.darkBorder", "context.colors.border"),
    ("AppColors.darkCard", "context.colors.surface"),
    ("AppColors.darkSurface", "context.colors.surfaceVariant"),
    ("AppColors.darkBackground", "context.colors.background"),
    ("AppColors.logoPlaceholder", "context.colors.surfaceVariant"),
    ("AppColors.logoInner", "context.colors.primary"),
    ("AppColors.illustrationBurgundy", "context.colors.primary"),
    ("AppColors.illustrationOrange", "context.colors.secondary"),
    ("AppColors.illustrationBlue", "context.colors.primary"),
    ("AppColors.illustrationGreen", "context.colors.success"),
]

DARK_TERNARY_PATTERNS = [
    (
        re.compile(
            r"isDark\s*\?\s*context\.colors\.surface\s*:\s*context\.colors\.surface"
        ),
        "context.colors.surface",
    ),
    (
        re.compile(
            r"isDark\s*\?\s*context\.colors\.background\s*:\s*context\.colors\.background"
        ),
        "context.colors.background",
    ),
    (
        re.compile(
            r"isDark\s*\?\s*context\.colors\.border\s*:\s*context\.colors\.border"
        ),
        "context.colors.border",
    ),
    (
        re.compile(
            r"isDark\s*\?\s*context\.colors\.textSecondary\s*:\s*context\.colors\.textSecondary"
        ),
        "context.colors.textSecondary",
    ),
    (
        re.compile(
            r"Theme\.of\(context\)\.brightness\s*==\s*Brightness\.dark\s*\?\s*context\.colors\.textTertiary\s*:\s*context\.colors\.textSecondary"
        ),
        "context.colors.textSecondary",
    ),
]


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def migrate_file(path: Path) -> bool:
    rel_path = rel(path)
    if rel_path in EXCLUDE:
        return False

    text = path.read_text()
    if "AppColors." not in text:
        return False

    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)

    for pattern, replacement in DARK_TERNARY_PATTERNS:
        text = pattern.sub(replacement, text)

    # Remove unused app_colors import when fully migrated
    if "AppColors." not in text:
        text = re.sub(
            r"import '\.\./theme/app_colors\.dart';\n", "", text
        )
        text = re.sub(
            r"import '\.\./\.\./core/theme/app_colors\.dart';\n", "", text
        )
        text = re.sub(
            r"import '\.\./\.\./\.\./core/theme/app_colors\.dart';\n", "", text
        )

    if "context.colors." in text and "theme_context.dart" not in text:
        if "import '../theme/" in text:
            text = text.replace(
                "import '../theme/app_spacing.dart';",
                "import '../theme/app_spacing.dart';\nimport '../theme/theme_context.dart';",
                1,
            )
        elif "import '../../core/theme/" in text:
            text = text.replace(
                "import '../../core/theme/app_spacing.dart';",
                "import '../../core/theme/app_spacing.dart';\nimport '../../core/theme/theme_context.dart';",
                1,
            )
        else:
            # generic insert after first import
            lines = text.splitlines()
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    lines.insert(i + 1, "import '../theme/theme_context.dart';")
                    text = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
                    break

    if text != original:
        path.write_text(text)
        return True
    return False


def main() -> None:
    changed = []
    for path in sorted(ROOT.rglob("*.dart")):
        if migrate_file(path):
            changed.append(rel(path))
    print(f"Migrated {len(changed)} files:")
    for item in changed:
        print(f"  - {item}")


if __name__ == "__main__":
    main()
