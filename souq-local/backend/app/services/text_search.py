"""Shared helpers for database text search."""


def escape_ilike(value: str) -> str:
    """Escape ILIKE wildcards so user input is matched literally."""
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
