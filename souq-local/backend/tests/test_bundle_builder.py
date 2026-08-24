"""Bundle builder routes — retired from the active Dribex product."""

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
async def test_bundle_templates_list_returns_410(client: AsyncClient):
    response = await client.get("/bundles/templates")
    assert response.status_code == 410
    assert "Bundle Builder" in response.json()["detail"]


@pytest.mark.asyncio
async def test_bundle_template_detail_returns_410(client: AsyncClient):
    response = await client.get("/bundles/templates/gaming-pc")
    assert response.status_code == 410
    assert "Bundle Builder" in response.json()["detail"]


@pytest.mark.asyncio
async def test_bundle_resolve_returns_410(client: AsyncClient):
    response = await client.post(
        "/bundles/resolve",
        json={
            "marketplace": "derb-ghallef",
            "template_slug": "gaming-pc",
            "slots": [{"key": "cpu", "label": "CPU", "category_slug": "electronics", "query": "cpu"}],
        },
    )
    assert response.status_code == 410
    assert "Bundle Builder" in response.json()["detail"]
