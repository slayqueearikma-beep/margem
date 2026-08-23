"""Curated bundle templates (configurable without code deploy via admin later)."""

from __future__ import annotations

GAMING_PC_SLOTS = [
    {"key": "cpu", "label": "CPU", "category_slug": "electronics", "query": "cpu"},
    {"key": "gpu", "label": "GPU", "category_slug": "electronics", "query": "gpu"},
    {"key": "ram", "label": "RAM", "category_slug": "electronics", "query": "ram"},
    {"key": "ssd", "label": "SSD", "category_slug": "electronics", "query": "ssd"},
    {"key": "motherboard", "label": "Motherboard", "category_slug": "electronics", "query": "motherboard"},
    {"key": "case", "label": "Case", "category_slug": "electronics", "query": "case"},
    {"key": "monitor", "label": "Monitor", "category_slug": "electronics", "query": "monitor"},
    {"key": "keyboard", "label": "Keyboard", "category_slug": "electronics", "query": "keyboard"},
    {"key": "mouse", "label": "Mouse", "category_slug": "electronics", "query": "mouse"},
]

PHONE_SETUP_SLOTS = [
    {"key": "phone", "label": "Phone", "category_slug": "electronics", "query": "phone"},
    {"key": "case", "label": "Case", "category_slug": "accessories", "query": "case"},
    {"key": "charger", "label": "Charger", "category_slug": "electronics", "query": "charger"},
    {"key": "earbuds", "label": "Earbuds", "category_slug": "electronics", "query": "earbuds"},
]

AUTO_MAINTENANCE_SLOTS = [
    {"key": "oil", "label": "Engine oil", "category_slug": "", "query": "oil"},
    {"key": "filter", "label": "Oil filter", "category_slug": "", "query": "filter"},
    {"key": "brakes", "label": "Brake pads", "category_slug": "", "query": "brake"},
    {"key": "tires", "label": "Tires", "category_slug": "", "query": "tire"},
    {"key": "service", "label": "Mechanic service", "category_slug": "", "query": "service"},
]

BUNDLE_TEMPLATES: list[dict] = [
    {
        "slug": "gaming-pc",
        "name": "Gaming PC",
        "description": "Build a complete gaming rig from parts across marketplace sellers.",
        "icon": "sports_esports",
        "marketplace_slug": "derb-ghallef",
        "slots": GAMING_PC_SLOTS,
    },
    {
        "slug": "phone-setup",
        "name": "Phone setup",
        "description": "Phone plus essentials — case, charger, and earbuds.",
        "icon": "smartphone",
        "marketplace_slug": "derb-ghallef",
        "slots": PHONE_SETUP_SLOTS,
    },
    {
        "slug": "auto-maintenance",
        "name": "Auto maintenance",
        "description": "Routine maintenance bundle for your car at Al Qurayaa (Souk Al Qurayaa).",
        "icon": "car_repair",
        "marketplace_slug": "9ri3a",
        "slots": AUTO_MAINTENANCE_SLOTS,
    },
]

BUNDLE_TEMPLATE_BY_SLUG = {item["slug"]: item for item in BUNDLE_TEMPLATES}
