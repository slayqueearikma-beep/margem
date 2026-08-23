"""Geography helpers — city registry, validation, and search."""

from __future__ import annotations

import re
from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.geography import City, Country

_CITY_BY_NAME: dict[str, City] = {}
_DEFAULT_CITY_NAME = "Casablanca"


def slugify_city(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")


def refresh_city_cache(cities: list[City]) -> None:
    global _CITY_BY_NAME
    lookup: dict[str, City] = {}
    for city in cities:
        if not city.is_active:
            continue
        for label in (city.name_en, city.name_fr, city.name_ar, city.slug):
            if label:
                lookup[label.casefold()] = city
    _CITY_BY_NAME = lookup


def resolve_city_name(value: str) -> str:
    cleaned = value.strip()
    if not cleaned:
        raise ValueError("City is required")
    city = _CITY_BY_NAME.get(cleaned.casefold())
    if city is None:
        raise ValueError(f"Unsupported city: {value}")
    return city.name_en


def get_cached_city(value: str) -> City | None:
    return _CITY_BY_NAME.get(value.strip().casefold())


def default_city_name() -> str:
    city = _CITY_BY_NAME.get(_DEFAULT_CITY_NAME.casefold())
    return city.name_en if city is not None else _DEFAULT_CITY_NAME


async def ensure_geography_seeded(session: AsyncSession) -> list[City]:
    """Load active cities into the in-memory registry."""
    result = await session.execute(
        select(City)
        .where(City.is_active.is_(True))
        .options(selectinload(City.country))
        .order_by(City.sort_order, City.name_en)
    )
    cities = list(result.scalars().all())
    refresh_city_cache(cities)
    return cities


async def list_cities(
    session: AsyncSession,
    *,
    country_code: str = "MA",
    query: str | None = None,
    active_only: bool = True,
) -> list[City]:
    stmt = (
        select(City)
        .join(Country)
        .where(Country.code == country_code.upper())
        .options(selectinload(City.country))
        .order_by(City.name_en)
    )
    if active_only:
        stmt = stmt.where(City.is_active.is_(True), Country.is_active.is_(True))
    if query:
        q = f"%{query.strip()}%"
        stmt = stmt.where(
            or_(
                City.name_en.ilike(q),
                City.name_fr.ilike(q),
                City.name_ar.ilike(q),
                City.slug.ilike(q),
            )
        )
    result = await session.execute(stmt)
    return list(result.scalars().all())


async def get_city_by_id(session: AsyncSession, city_id: UUID) -> City | None:
    return await session.scalar(
        select(City)
        .where(City.id == city_id, City.is_active.is_(True))
        .options(selectinload(City.country))
    )
