import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_legal_privacy_en(client: AsyncClient):
    res = await client.get("/legal/en/privacy")
    assert res.status_code == 200
    assert "text/html" in res.headers.get("content-type", "")
    assert "Privacy Policy" in res.text


@pytest.mark.asyncio
async def test_legal_privacy_ar_rtl(client: AsyncClient):
    res = await client.get("/legal/ar/privacy")
    assert res.status_code == 200
    assert 'dir="rtl"' in res.text
    assert "سياسة الخصوصية" in res.text


@pytest.mark.asyncio
async def test_privacy_redirect(client: AsyncClient):
    res = await client.get("/privacy", follow_redirects=False)
    assert res.status_code == 302
    assert "/legal/" in res.headers["location"]
