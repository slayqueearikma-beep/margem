"""Bundle builder resolution across marketplace sellers."""

from uuid import UUID, uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

import app.database as database
from app.main import app
from app.models import Marketplace, SellerProfile
from tests.auth_helpers import register_test_user

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register_seller(client: AsyncClient, business_name: str) -> tuple[dict, UUID]:
    email = f"seller-{uuid4().hex[:8]}@example.com"
    tokens = await register_test_user(
        client,
        email=email,
        account_type="seller",
        display_name=business_name,
    )
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    profile = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": business_name,
            "description": "PC parts",
            "address": "Derb Ghallef",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.61,
            "phone": "+212600000011",
            "whatsapp_number": "+212600000011",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
            "seller_terms_acknowledged": True,
            "acceptance_language": "en"
        },
    )
    assert profile.status_code == 201, profile.text
    return headers, UUID(profile.json()["id"])


async def _attach_marketplace(seller_id: UUID, slug: str = "derb-ghallef") -> UUID:
    async with database.SessionLocal() as session:
        marketplace_id = await session.scalar(select(Marketplace.id).where(Marketplace.slug == slug))
        if marketplace_id is None:
            marketplace_id = uuid4()
            session.add(
                Marketplace(
                    id=marketplace_id,
                    slug=slug,
                    name="Derb Ghallef",
                    description="Electronics",
                    city="Casablanca",
                )
            )
            await session.flush()
        seller = await session.get(SellerProfile, seller_id)
        assert seller is not None
        seller.marketplace_id = marketplace_id
        await session.commit()
        return marketplace_id


async def _add_product(
    client: AsyncClient,
    headers: dict,
    seller_id: UUID,
    *,
    name: str,
    price: float,
    category_slug: str,
    warranty_note: str = "",
) -> dict:
    response = await client.post(
        f"/sellers/{seller_id}/products",
        headers=headers,
        json={
            "name": name,
            "description": name,
            "price_mad": price,
            "category_slug": category_slug,
            "warranty_note": warranty_note,
            "accepted_payment_methods": ["cash"],
            "delivery_options": ["pickup"],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_bundle_templates_list(client: AsyncClient):
    response = await client.get("/bundles/templates")
    assert response.status_code == 200
    slugs = [item["slug"] for item in response.json()]
    assert "gaming-pc" in slugs


@pytest.mark.asyncio
async def test_bundle_resolve_picks_cheapest_best_across_sellers(client: AsyncClient):
    headers_a, seller_a = await _register_seller(client, "Tech Alpha")
    headers_b, seller_b = await _register_seller(client, "Tech Beta")
    await _attach_marketplace(seller_a)
    await _attach_marketplace(seller_b)

    await _add_product(
        client, headers_a, seller_a, name="Intel CPU i7", price=3200, category_slug="electronics", warranty_note="12 months"
    )
    await _add_product(
        client, headers_b, seller_b, name="Budget CPU", price=2800, category_slug="electronics", warranty_note="6 months"
    )
    await _add_product(
        client, headers_a, seller_a, name="Entry GPU", price=3900, category_slug="electronics"
    )
    await _add_product(
        client, headers_b, seller_b, name="RTX GPU", price=4500, category_slug="electronics", warranty_note="24 months"
    )

    response = await client.post(
        "/bundles/resolve",
        json={
            "marketplace": "derb-ghallef",
            "template_slug": "gaming-pc",
            "slots": [
                {"key": "cpu", "label": "CPU", "category_slug": "electronics", "query": "cpu"},
                {"key": "gpu", "label": "GPU", "category_slug": "electronics", "query": "gpu"},
            ],
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["slots_matched"] == 2
    assert body["total_price_mad"] == 6700
    assert body["savings_mad"] >= 0
    assert len(body["seller_breakdown"]) == 2
    assert body["all_available"] is True
    cpu_pick = next(item for item in body["picks"] if item["slot_key"] == "cpu")
    assert cpu_pick["product_name"] == "Budget CPU"
    assert cpu_pick["warranty_note"] == "6 months"


@pytest.mark.asyncio
async def test_bundle_resolve_unknown_marketplace(client: AsyncClient):
    response = await client.post(
        "/bundles/resolve",
        json={
            "marketplace": "missing-market",
            "slots": [{"key": "cpu", "label": "CPU", "category_slug": "computers", "query": "cpu"}],
        },
    )
    assert response.status_code == 404
