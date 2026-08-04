"""Moroccan city registry tests."""

import pytest
from pydantic import ValidationError

from app.schemas import SellerCreate
from app.services.geography import refresh_city_cache
from app.models.geography import City
from uuid import uuid4


def _seed_cache() -> None:
    morocco_id = uuid4()
    cities = [
        City(
            id=uuid4(),
            country_id=morocco_id,
            slug="casablanca",
            name_en="Casablanca",
            name_fr="Casablanca",
            name_ar="الدار البيضاء",
            region="Casablanca-Settat",
            latitude=33.5731,
            longitude=-7.5898,
            is_active=True,
            sort_order=1,
        ),
        City(
            id=uuid4(),
            country_id=morocco_id,
            slug="rabat",
            name_en="Rabat",
            name_fr="Rabat",
            name_ar="الرباط",
            region="Rabat-Salé-Kénitra",
            latitude=34.0209,
            longitude=-6.8416,
            is_active=True,
            sort_order=2,
        ),
    ]
    refresh_city_cache(cities)


def test_seller_create_rejects_unknown_city():
    _seed_cache()
    with pytest.raises(ValidationError, match="Unsupported city"):
        SellerCreate(
            business_name="Shop",
            address="12 Rue Example",
            city="Paris",
            latitude=34.0,
            longitude=-6.8,
            phone="+212600000099",
        )


def test_seller_create_accepts_casablanca_and_rabat():
    _seed_cache()
    casablanca = SellerCreate(
        business_name="Shop",
        address="12 Rue Example",
        city="casablanca",
        latitude=33.57,
        longitude=-7.58,
        phone="+212600000099",
    )
    assert casablanca.city == "Casablanca"

    rabat = SellerCreate(
        business_name="Shop Rabat",
        address="1 Avenue Mohammed V",
        city="Rabat",
        latitude=34.02,
        longitude=-6.84,
        phone="+212600000099",
    )
    assert rabat.city == "Rabat"
