"""Geography cities API."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_list_morocco_cities(client: AsyncClient):
    response = await client.get("/geography/cities", params={"country": "MA"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) >= 20
    names = {item["name_en"] for item in items}
    assert "Casablanca" in names
    assert "Rabat" in names
    assert "Marrakech" in names


@pytest.mark.asyncio
async def test_search_cities(client: AsyncClient):
    response = await client.get("/geography/cities", params={"country": "MA", "q": "fes"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert any(item["slug"] == "fes" for item in items)
