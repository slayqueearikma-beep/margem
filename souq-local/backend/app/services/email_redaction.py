"""Safe logging helpers for transactional email."""

from __future__ import annotations

import re

_TOKEN_RE = re.compile(r"(token=)([A-Za-z0-9_\-]{8,})", re.IGNORECASE)
_BEARERISH_RE = re.compile(r"\b([A-Za-z0-9_\-]{24,})\b")
_OTP_RE = re.compile(r"\b\d{6}\b")


def safe_preview(text: str, limit: int = 200) -> str:
    redacted = _TOKEN_RE.sub(r"\1[REDACTED]", text)
    redacted = _OTP_RE.sub("[REDACTED]", redacted)
    if "token" in text.lower() or "reset" in text.lower() or "verify" in text.lower():
        redacted = _BEARERISH_RE.sub("[REDACTED]", redacted)
    return redacted.replace("\n", " ")[:limit]


def mask_email(address: str) -> str:
    value = (address or "").strip()
    if "@" not in value:
        return "[redacted]"
    local, _, domain = value.partition("@")
    if not local:
        return f"[redacted]@{domain}"
    return f"{local[0]}***@{domain}"
