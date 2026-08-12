"""Geography helpers — city registry, validation, and search."""

from __future__ import annotations

import re
import uuid

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.community import City
from app.models.geography import Country
from app.services.text_search import escape_ilike

MOROCCO_ID = uuid.UUID("00000000-0000-4000-8000-000000000001")

MOROCCO_CITIES = [
    ("casablanca", "Casablanca", "Casablanca", "الدار البيضاء", "Casablanca-Settat", 33.5731, -7.5898, 1),
    ("rabat", "Rabat", "Rabat", "الرباط", "Rabat-Salé-Kénitra", 34.0209, -6.8416, 2),
    ("marrakech", "Marrakech", "Marrakech", "مراكش", "Marrakech-Safi", 31.6295, -7.9811, 3),
    ("fes", "Fes", "Fès", "فاس", "Fès-Meknès", 34.0331, -5.0003, 4),
    ("tangier", "Tangier", "Tanger", "طنجة", "Tangier-Tetouan-Al Hoceima", 35.7595, -5.8340, 5),
    ("agadir", "Agadir", "Agadir", "أكادير", "Souss-Massa", 30.4278, -9.5981, 6),
    ("meknes", "Meknes", "Meknès", "مكناس", "Fès-Meknès", 33.8935, -5.5473, 7),
    ("oujda", "Oujda", "Oujda", "وجدة", "Oriental", 34.6814, -1.9086, 8),
    ("kenitra", "Kenitra", "Kénitra", "القنيطرة", "Rabat-Salé-Kénitra", 34.2610, -6.5802, 9),
    ("tetouan", "Tetouan", "Tétouan", "تطوان", "Tangier-Tetouan-Al Hoceima", 35.5889, -5.3626, 10),
    ("sale", "Sale", "Salé", "سلا", "Rabat-Salé-Kénitra", 34.0531, -6.7985, 11),
    ("nador", "Nador", "Nador", "الناظور", "Oriental", 35.1688, -2.9286, 12),
    ("mohammedia", "Mohammedia", "Mohammedia", "المحمدية", "Casablanca-Settat", 33.6866, -7.3830, 13),
    ("el-jadida", "El Jadida", "El Jadida", "الجديدة", "Casablanca-Settat", 33.2316, -8.5007, 14),
    ("beni-mellal", "Beni Mellal", "Béni Mellal", "بني ملال", "Béni Mellal-Khénifra", 32.3373, -6.3498, 15),
    ("khouribga", "Khouribga", "Khouribga", "خريبكة", "Béni Mellal-Khénifra", 32.8867, -6.9209, 16),
    ("taza", "Taza", "Taza", "تازة", "Fès-Meknès", 34.2139, -4.0086, 17),
    ("settat", "Settat", "Settat", "سطات", "Casablanca-Settat", 33.0019, -7.6169, 18),
    ("larache", "Larache", "Larache", "العرائش", "Tangier-Tetouan-Al Hoceima", 35.1874, -6.1557, 19),
    ("safi", "Safi", "Safi", "آسفي", "Marrakech-Safi", 32.2994, -9.2372, 20),
]

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
        display = city.name_en or city.name
        for label in (display, city.name_fr, city.name_ar, city.slug, city.name):
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
    return city.name_en or city.name


def get_cached_city(value: str) -> City | None:
    return _CITY_BY_NAME.get(value.strip().casefold())


def default_city_name() -> str:
    city = _CITY_BY_NAME.get(_DEFAULT_CITY_NAME.casefold())
    if city is not None:
        return city.name_en or city.name
    return _DEFAULT_CITY_NAME


async def seed_morocco_cities_if_empty(session: AsyncSession) -> None:
    """Idempotent Morocco registry for dev/test environments using create_all."""
    existing = await session.scalar(select(Country).where(Country.code == "MA"))
    if existing is None:
        session.add(
            Country(
                id=MOROCCO_ID,
                code="MA",
                name_en="Morocco",
                name_ar="المغرب",
                name_fr="Maroc",
                is_active=True,
            )
        )
        await session.flush()

    for slug, name_en, name_fr, name_ar, region, lat, lng, sort_order in MOROCCO_CITIES:
        city = await session.scalar(select(City).where(City.slug == slug))
        if city is None:
            session.add(
                City(
                    id=uuid.uuid4(),
                    country_id=MOROCCO_ID,
                    slug=slug,
                    name=name_en,
                    name_en=name_en,
                    name_fr=name_fr,
                    name_ar=name_ar,
                    region=region,
                    latitude=lat,
                    longitude=lng,
                    sort_order=sort_order,
                    description=f"Dribex community for {name_en}",
                    is_active=True,
                )
            )
        else:
            city.country_id = MOROCCO_ID
            city.name = name_en
            city.name_en = name_en
            city.name_fr = name_fr
            city.name_ar = name_ar
            city.region = region
            city.latitude = lat
            city.longitude = lng
            city.sort_order = sort_order
            city.is_active = True
    await session.commit()


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
        .order_by(City.sort_order, City.name_en)
    )
    if active_only:
        stmt = stmt.where(City.is_active.is_(True), Country.is_active.is_(True))
    if query:
        q = f"%{escape_ilike(query.strip())}%"
        stmt = stmt.where(
            or_(
                City.name_en.ilike(q),
                City.name_fr.ilike(q),
                City.name_ar.ilike(q),
                City.slug.ilike(q),
                City.name.ilike(q),
            )
        )
    result = await session.execute(stmt)
    return list(result.scalars().all())


async def get_city_by_id(session: AsyncSession, city_id) -> City | None:
    return await session.scalar(
        select(City)
        .where(City.id == city_id, City.is_active.is_(True))
        .options(selectinload(City.country))
    )
