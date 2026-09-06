"""Sanitize user-supplied free text before persistence."""

from __future__ import annotations

import re

_CONTROL_CHARS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def sanitize_free_text(value: str, *, max_length: int) -> str:
    """Strip control characters and enforce a maximum length."""
    cleaned = _CONTROL_CHARS.sub("", (value or "").strip())
    return cleaned[:max_length]
