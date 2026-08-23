"""Business category taxonomy tests."""

from __future__ import annotations

import pytest
from httpx import ASGITransport, AsyncClient

from app.data.business_categories import BUSINESS_CATEGORIES
from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_categories_include_business_taxonomy(client: AsyncClient):
    res = await client.get("/categories")
    assert res.status_code == 200
    slugs = {item["slug"] for item in res.json()}
    expected = {cat.slug for cat in BUSINESS_CATEGORIES}
    assert expected.issubset(slugs)


@pytest.mark.asyncio
async def test_category_payload_has_localized_names_and_accent(client: AsyncClient):
    res = await client.get("/categories")
    doctors = next(item for item in res.json() if item["slug"] == "doctors")
    assert doctors["name_en"] == "Doctors"
    assert doctors["name_fr"] == "Médecins"
    assert doctors["name_ar"] == "أطباء"
    assert doctors["icon"] == "medical_services"
    assert doctors["accent_color"].startswith("#")
