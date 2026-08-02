import pytest
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError

from app.main import app
from app.services.service_pricing import PricingModel, normalize_service_pricing

pytestmark = pytest.mark.usefixtures("prepare_database")


async def _register(client: AsyncClient, email: str) -> dict:
    response = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": "SecurePass1",
            "account_type": "seller",
            "display_name": email.split("@")[0],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def _create_seller(client: AsyncClient, token: str) -> dict:
    response = await client.post(
        "/sellers",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "business_name": "Service Shop",
            "description": "Desc",
            "address": "1 Main Street",
            "city": "Casablanca",
            "latitude": 33.5,
            "longitude": -7.6,
            "phone": "+212600000000",
            "cover_image_url": "",
            "logo_image_url": "",
            "opening_hours": {
                "days": {"Mon": True, "Tue": True, "Wed": True, "Thu": True, "Fri": True, "Sat": True, "Sun": False},
                "open": "09:00",
                "close": "21:00",
            },
            "category_ids": [],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        (
            {"pricing_model": "fixed_price", "price_mad": 250},
            {"pricing_model": "fixed_price", "price_mad": 250, "price_min_mad": None, "price_max_mad": None},
        ),
        (
            {"pricing_model": "price_range", "price_min_mad": 100, "price_max_mad": 500},
            {"pricing_model": "price_range", "price_mad": None, "price_min_mad": 100, "price_max_mad": 500},
        ),
        (
            {"pricing_model": "request_quote"},
            {"pricing_model": "request_quote", "price_mad": None, "price_min_mad": None, "price_max_mad": None},
        ),
        (
            {"pricing_model": "free"},
            {"pricing_model": "free", "price_mad": 0.0, "price_min_mad": None, "price_max_mad": None},
        ),
    ],
)
def test_normalize_service_pricing(payload, expected):
    result = normalize_service_pricing(payload)
    for key, value in expected.items():
        assert result[key] == value


def test_normalize_service_pricing_rejects_invalid_range():
    with pytest.raises(ValidationError):
        normalize_service_pricing(
            {"pricing_model": PricingModel.PRICE_RANGE, "price_min_mad": 500, "price_max_mad": 100}
        )


@pytest.mark.asyncio
async def test_service_pricing_crud():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        seller = await _register(client, "service-pricing@example.com")
        token = seller["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        created = await _create_seller(client, token)
        seller_id = created["id"]

        created_service = await client.post(
            f"/sellers/{seller_id}/services",
            headers=headers,
            json={
                "name": "Home cleaning",
                "description": "Weekly service",
                "pricing_model": "hourly",
                "price_mad": 80,
            },
        )
        assert created_service.status_code == 201, created_service.text
        body = created_service.json()
        assert body["pricing_model"] == "hourly"
        assert body["price_mad"] == 80
        service_id = body["id"]

        updated = await client.patch(
            f"/sellers/{seller_id}/services/{service_id}",
            headers=headers,
            json={
                "pricing_model": "price_range",
                "price_min_mad": 200,
                "price_max_mad": 600,
            },
        )
        assert updated.status_code == 200, updated.text
        updated_body = updated.json()
        assert updated_body["pricing_model"] == "price_range"
        assert updated_body["price_min_mad"] == 200
        assert updated_body["price_max_mad"] == 600
        assert updated_body["price_mad"] is None

        detail = await client.get(f"/sellers/{seller_id}")
        assert detail.status_code == 200, detail.text
        services = detail.json()["services"]
        assert len(services) == 1
        assert services[0]["pricing_model"] == "price_range"

        legacy = await client.post(
            f"/sellers/{seller_id}/services",
            headers=headers,
            json={"name": "Legacy", "description": "Old price only", "price_mad": 150},
        )
        assert legacy.status_code == 201, legacy.text
        assert legacy.json()["pricing_model"] == "fixed_price"
