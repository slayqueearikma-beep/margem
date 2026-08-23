"""Public geography endpoints — countries and cities."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.geography import CityListResponse, CityOut, CountryOut
from app.services.geography import list_cities

router = APIRouter(prefix="/geography", tags=["geography"])


@router.get("/cities", response_model=CityListResponse)
async def get_cities(
    country: str = Query(default="MA", min_length=2, max_length=2),
    q: str | None = Query(default=None, max_length=80),
    session: AsyncSession = Depends(get_db),
) -> CityListResponse:
    cities = await list_cities(session, country_code=country, query=q)
    return CityListResponse(
        items=[
            CityOut(
                id=city.id,
                slug=city.slug,
                name_en=city.name_en,
                name_ar=city.name_ar,
                name_fr=city.name_fr,
                region=city.region,
                latitude=city.latitude,
                longitude=city.longitude,
                is_active=city.is_active,
                sort_order=city.sort_order,
                country=CountryOut.model_validate(city.country),
            )
            for city in cities
        ]
    )
