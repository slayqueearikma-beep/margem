#!/usr/bin/env python3
"""End-to-end marketplace visibility trace for Seller A/B and Buyer C."""

from __future__ import annotations

import asyncio
import os
from uuid import uuid4

from httpx import ASGITransport, AsyncClient

os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://souq:souq_local_dev@localhost:5432/souq_local")
os.environ.setdefault("JWT_SECRET_KEY", "audit-jwt-secret-key-minimum-32-characters")
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("AUTH_DEV_BYPASS", "false")

from app.main import app  # noqa: E402
from tests.auth_helpers import register_test_user  # noqa: E402
from tests.conftest import prepare_database  # noqa: E402
from tests.seller_helpers import create_test_seller, seller_create_payload  # noqa: E402


async def _register(client: AsyncClient, account_type: str) -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    normalized = "provider" if account_type == "seller" else account_type
    tokens = await register_test_user(
        client,
        email=email,
        account_type=normalized,
        display_name=account_type.title(),
    )
    return {"headers": {"Authorization": f"Bearer {tokens['access_token']}"}}


async def _create_listings(
    client: AsyncClient,
    headers: dict,
    *,
    business_name: str,
    product_name: str,
    service_name: str,
) -> tuple[str, str]:
    seller = await create_test_seller(
        client,
        headers,
        **seller_create_payload(business_name=business_name),
    )
    product = await client.post(
        f"/sellers/{seller['id']}/products",
        headers=headers,
        json={"name": product_name, "description": "trace", "price_mad": 100},
    )
    assert product.status_code == 201, product.text
    service = await client.post(
        f"/sellers/{seller['id']}/services",
        headers=headers,
        json={"name": service_name, "description": "trace", "price_mad": 200},
    )
    assert service.status_code == 201, service.text
    return product.json()["id"], service.json()["id"]


async def run_trace() -> None:
    async for _ in prepare_database():
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            seller_a = await _register(client, "seller")
            seller_b = await _register(client, "seller")
            buyer_c = await _register(client, "buyer")

            product_a, service_a = await _create_listings(
                client,
                seller_a["headers"],
                business_name="Shop Alpha",
                product_name="Alpha Widget",
                service_name="Alpha Repair",
            )
            product_b, service_b = await _create_listings(
                client,
                seller_b["headers"],
                business_name="Shop Beta",
                product_name="Beta Gadget",
                service_name="Beta Cleaning",
            )

            search = await client.get("/search", params={"mode": "all", "limit": 50})
            assert search.status_code == 200, search.text
            body = search.json()

            buyer_search = await client.get(
                "/search",
                params={"mode": "all", "limit": 50},
                headers=buyer_c["headers"],
            )
            assert buyer_search.status_code == 200, buyer_search.text
            buyer_body = buyer_search.json()

            services_page = await client.get("/services", params={"limit": 50})
            assert services_page.status_code == 200, services_page.text

            print("DATABASE/API TRACE (synthetic test DB)")
            print(f"API products (anonymous): {len(body['products'])}")
            print(f"API services (anonymous): {len(body['services'])}")
            print(f"API sellers/providers (anonymous): {len(body['sellers'])}")
            print(f"API products (buyer C): {len(buyer_body['products'])}")
            print(f"API services (buyer C): {len(buyer_body['services'])}")
            print(f"Catalog /services items: {len(services_page.json()['items'])}")

            product_ids = {item["id"] for item in body["products"]}
            service_ids = {item["id"] for item in body["services"]}
            checks = {
                "buyer sees product A": product_a in product_ids,
                "buyer sees product B": product_b in product_ids,
                "buyer sees service A": service_a in service_ids,
                "buyer sees service B": service_b in service_ids,
                "buyer C sees both products": {
                    product_a,
                    product_b,
                }.issubset({item["id"] for item in buyer_body["products"]}),
            }
            for label, ok in checks.items():
                print(f"{label}: {'PASS' if ok else 'FAIL'}")
        break


if __name__ == "__main__":
    asyncio.run(run_trace())
