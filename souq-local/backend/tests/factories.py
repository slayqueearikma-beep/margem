"""Shared test payload builders."""

from __future__ import annotations

_CATEGORY_IDS: list[str] = []


def set_category_ids(ids: list[str]) -> None:
    global _CATEGORY_IDS
    _CATEGORY_IDS = ids


def sample_category_ids(count: int = 1) -> list[str]:
    if not _CATEGORY_IDS:
        raise RuntimeError("Test categories are not seeded")
    return _CATEGORY_IDS[:count]


def seller_create_payload(**overrides) -> dict:
    payload = {
        "business_name": "Test Shop",
        "description": "Desc",
        "address": "1 Main Street",
        "city": "Casablanca",
        "latitude": 33.5,
        "longitude": -7.6,
        "phone": "+212600000000",
        "cover_image_url": "",
        "logo_image_url": "",
        "opening_hours": {
            "days": {
                "Mon": True,
                "Tue": True,
                "Wed": True,
                "Thu": True,
                "Fri": True,
                "Sat": True,
                "Sun": False,
            },
            "open": "09:00",
            "close": "21:00",
        },
        "category_ids": sample_category_ids(1),
    }
    payload.update(overrides)
    return payload
