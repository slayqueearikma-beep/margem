"""Moroccan city validation via geography registry."""

import pytest
from pydantic import ValidationError

from app.schemas import SellerCreate
from app.services.geography import refresh_city_cache
from app.models.community import City
from app.models.geography import Country
from uuid import uuid4


def _seed_city_cache() -> None:
    morocco = Country(
        id=uuid4(),
        code="MA",
        name_en="Morocco",
        name_ar="المغرب",
        name_fr="Maroc",
        is_active=True,
    )
    cities = [
        City(
            id=uuid4(),
            slug="casablanca",
            name="Casablanca",
            name_en="Casablanca",
            name_fr="Casablanca",
            name_ar="الدار البيضاء",
            region="Casablanca-Settat",
            latitude=33.5731,
            longitude=-7.5898,
            sort_order=1,
            country=morocco,
            is_active=True,
        ),
        City(
            id=uuid4(),
            slug="rabat",
            name="Rabat",
            name_en="Rabat",
            name_fr="Rabat",
            name_ar="الرباط",
            region="Rabat-Salé-Kénitra",
            latitude=34.0209,
            longitude=-6.8416,
            sort_order=2,
            country=morocco,
            is_active=True,
        ),
    ]
    refresh_city_cache(cities)


@pytest.fixture(autouse=True)
def _city_cache():
    _seed_city_cache()


def test_seller_create_rejects_unknown_city():
    with pytest.raises(ValidationError, match="Unsupported city"):
        SellerCreate(
            business_name="Shop",
            address="12 Rue Example",
            city="Paris",
            latitude=34.0,
            longitude=-6.8,
            phone="+212600000099",
        )


def test_seller_create_accepts_casablanca():
    payload = SellerCreate(
        business_name="Shop",
        address="12 Rue Example",
        city="casablanca",
        latitude=33.57,
        longitude=-7.58,
        phone="+212600000099",
    )
    assert payload.city == "Casablanca"


def test_seller_create_accepts_rabat():
    payload = SellerCreate(
        business_name="Shop",
        address="12 Rue Example",
        city="Rabat",
        latitude=34.02,
        longitude=-6.84,
        phone="+212600000099",
    )
    assert payload.city == "Rabat"
