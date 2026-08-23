"""Role-based permissions for partnership members."""

from __future__ import annotations

from app.models.partnership import PartnershipMember, PartnershipMemberRole

PERMISSION_KEYS = (
    "product_management",
    "inventory_management",
    "order_management",
    "pricing",
    "analytics",
    "team_management",
    "messaging",
    "partnership_settings",
)

ROLE_DEFAULTS: dict[PartnershipMemberRole, dict[str, bool]] = {
    PartnershipMemberRole.OWNER: {key: True for key in PERMISSION_KEYS},
    PartnershipMemberRole.PARTNER: {
        "product_management": True,
        "inventory_management": True,
        "order_management": True,
        "pricing": True,
        "analytics": True,
        "team_management": False,
        "messaging": True,
        "partnership_settings": True,
    },
    PartnershipMemberRole.MANAGER: {
        "product_management": True,
        "inventory_management": True,
        "order_management": True,
        "pricing": True,
        "analytics": True,
        "team_management": False,
        "messaging": True,
        "partnership_settings": False,
    },
    PartnershipMemberRole.INVENTORY_MANAGER: {
        "product_management": True,
        "inventory_management": True,
        "order_management": False,
        "pricing": False,
        "analytics": True,
        "team_management": False,
        "messaging": True,
        "partnership_settings": False,
    },
    PartnershipMemberRole.SALES_MANAGER: {
        "product_management": True,
        "inventory_management": False,
        "order_management": True,
        "pricing": True,
        "analytics": True,
        "team_management": False,
        "messaging": True,
        "partnership_settings": False,
    },
    PartnershipMemberRole.CUSTOMER_SUPPORT: {
        "product_management": False,
        "inventory_management": False,
        "order_management": True,
        "pricing": False,
        "analytics": False,
        "team_management": False,
        "messaging": True,
        "partnership_settings": False,
    },
}


def effective_permissions(member: PartnershipMember) -> dict[str, bool]:
    base = dict(ROLE_DEFAULTS.get(member.role, {}))
    overrides = member.permissions or {}
    for key in PERMISSION_KEYS:
        if key in overrides:
            base[key] = bool(overrides[key])
    return base


def has_permission(member: PartnershipMember, permission: str) -> bool:
    if not member.is_active:
        return False
    return effective_permissions(member).get(permission, False)


def permissions_out(member: PartnershipMember) -> dict[str, bool]:
    return effective_permissions(member)
