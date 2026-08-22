"""Production QR share-link tests."""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.mark.asyncio
async def test_share_link_resolve_seller():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await register_test_user(client, email="qr-seller@example.com", account_type="seller")
        headers = {"Authorization": f"Bearer {seller['access_token']}"}

        created = await client.post(
            "/sellers",
            headers=headers,
            json={
                "business_name": "QR Shop",
                "description": "Test",
                "address": "1 Main Street",
                "city": "Casablanca",
                "latitude": 33.57,
                "longitude": -7.59,
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
                "category_ids": [],
                "seller_terms_acknowledged": True,
                "acceptance_language": "en",
            },
        )
        assert created.status_code == 201, created.text
        seller_id = created.json()["id"]

        link = await client.post(f"/sellers/{seller_id}/share-link", headers=headers)
        assert link.status_code == 200, link.text
        token = link.json()["token"]

        public = await client.get(f"/p/{token}")
        assert public.status_code == 200, public.text
        body = public.json()
        assert body["type"] == "seller"
        assert body["business_name"] == "QR Shop"
