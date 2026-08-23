"""Shared path matching for admin/staff API network guards."""


def is_admin_protected_path(path: str) -> bool:
    """True for routes that require admin/staff JWT and should honor IP/origin guards."""
    normalized = (path.split("?", 1)[0]).rstrip("/") or "/"
    if normalized == "/admin" or normalized.startswith("/admin/"):
        return True
    if normalized == "/billing/admin" or normalized.startswith("/billing/admin/"):
        return True
    # Community and marketplace moderation consoles live outside /admin/*.
    if "/community/admin" in normalized:
        return True
    return False
