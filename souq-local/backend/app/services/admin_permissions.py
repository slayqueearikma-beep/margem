"""Role-based access control for the MarGem administration system."""

from __future__ import annotations

from fastapi import HTTPException, status

from app.models import UserRole

# Roles that may access any admin route.
STAFF_ROLES: frozenset[UserRole] = frozenset(
    {
        UserRole.SUPER_ADMIN,
        UserRole.ADMIN,
        UserRole.MODERATOR,
        UserRole.SUPPORT,
    }
)

# Full operational write access (users, premium, categories, announcements).
ADMIN_WRITE_ROLES: frozenset[UserRole] = frozenset(
    {UserRole.SUPER_ADMIN, UserRole.ADMIN}
)

# Content moderation (reports, listings, business verification).
MODERATOR_WRITE_ROLES: frozenset[UserRole] = frozenset(
    {UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.MODERATOR}
)

SUPER_ADMIN_ROLES: frozenset[UserRole] = frozenset({UserRole.SUPER_ADMIN})


def is_staff(role: UserRole) -> bool:
    return role in STAFF_ROLES


def role_label(role: UserRole) -> str:
    return {
        UserRole.SUPER_ADMIN: "Super Admin",
        UserRole.ADMIN: "Admin",
        UserRole.MODERATOR: "Moderator",
        UserRole.SUPPORT: "Support (read-only)",
        UserRole.BUYER: "Buyer",
        UserRole.SELLER: "Seller",
    }.get(role, role.value)


def require_role(user_role: UserRole, allowed: frozenset[UserRole], *, detail: str) -> None:
    if user_role not in allowed:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


PERMISSIONS: dict[str, frozenset[UserRole]] = {
    "dashboard.view": STAFF_ROLES,
    "users.view": STAFF_ROLES,
    "users.write": ADMIN_WRITE_ROLES,
    "users.role": SUPER_ADMIN_ROLES,
    "businesses.view": STAFF_ROLES,
    "businesses.moderate": MODERATOR_WRITE_ROLES,
    "listings.view": STAFF_ROLES,
    "listings.moderate": MODERATOR_WRITE_ROLES,
    "reports.view": STAFF_ROLES,
    "reports.moderate": MODERATOR_WRITE_ROLES,
    "categories.view": STAFF_ROLES,
    "categories.write": ADMIN_WRITE_ROLES,
    "premium.view": STAFF_ROLES,
    "premium.write": ADMIN_WRITE_ROLES,
    "analytics.view": STAFF_ROLES,
    "notifications.send": ADMIN_WRITE_ROLES,
    "audit.view": STAFF_ROLES,
}


def assert_permission(role: UserRole, permission: str) -> None:
    allowed = PERMISSIONS.get(permission)
    if allowed is None or role not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Permission denied: {permission}",
        )
