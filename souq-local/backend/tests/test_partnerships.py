"""Business partnership & teaming system tests."""

from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.usefixtures("prepare_database")


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _register(client: AsyncClient, account_type: str, name: str) -> dict:
    email = f"{account_type}-{uuid4().hex[:8]}@example.com"
    password = "SecurePass1"
    res = await client.post(
        "/auth/register",
        json={
            "email": email,
            "password": password,
            "account_type": account_type,
            "display_name": name,
        },
    )
    assert res.status_code == 201, res.text
    body = res.json()
    return {
        "email": email,
        "password": password,
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
        "user_id": body["user"]["id"],
    }


async def _verify_email(client: AsyncClient, headers: dict) -> None:
    await client.post("/auth/verify-email/request", headers=headers)
    # Dev bypass: mark verified via direct DB not available; use seller without verify for list
    # create_partnership uses require_verified_email - need to check test auth bypass


async def _create_store(client: AsyncClient, headers: dict, name: str) -> dict:
    res = await client.post(
        "/sellers",
        headers=headers,
        json={
            "business_name": name,
            "description": "Partnership test store",
            "address": "12 Rue Example",
            "city": "Casablanca",
            "latitude": 33.57,
            "longitude": -7.62,
            "phone": "+212600000077",
            "whatsapp_number": "+212600000077",
            "payment_methods": ["cash"],
            "delivery_methods": ["in_store"],
        },
    )
    assert res.status_code == 201, res.text
    return res.json()


async def _create_product(client: AsyncClient, headers: dict, seller_id: str) -> dict:
    res = await client.post(
        f"/sellers/{seller_id}/products",
        headers=headers,
        json={
            "name": "Partnership Product",
            "description": "Shared listing test",
            "price_mad": 500,
            "category_slug": "electronics",
            "stock_quantity": 10,
        },
    )
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.asyncio
async def test_partnership_invite_accept_and_listing(client: AsyncClient):
    seller_a = await _register(client, "seller", "Partner A")
    seller_b = await _register(client, "seller", "Partner B")
    store_a = await _create_store(client, seller_a["headers"], "Store Alpha")
    store_b = await _create_store(client, seller_b["headers"], "Store Beta")

    # Verify emails for partnership create
    for headers in (seller_a["headers"], seller_b["headers"]):
        req = await client.post("/auth/verify-email/request", headers=headers)
        assert req.status_code in (200, 204), req.text

    # Manually verify via patch if endpoint exists, else skip create and use mock
    from app.database import SessionLocal
    from app.models import User
    from datetime import UTC, datetime
    from sqlalchemy import update

    async with SessionLocal() as session:
        await session.execute(
            update(User)
            .where(User.id.in_([seller_a["user_id"], seller_b["user_id"]]))
            .values(email_verified_at=datetime.now(UTC))
        )
        await session.commit()

    created = await client.post(
        "/partnerships",
        headers=seller_a["headers"],
        json={
            "name": "Alpha Beta Alliance",
            "description": "Joint electronics partnership",
            "partnership_type": "supplier_retailer",
            "marketplace_slug": "derb-ghallef",
            "category_slugs": ["electronics"],
            "default_revenue_splits": [
                {"seller_id": store_a["id"], "percentage": 60},
                {"seller_id": store_b["id"], "percentage": 40},
            ],
        },
    )
    assert created.status_code == 201, created.text
    partnership = created.json()
    partnership_id = partnership["id"]
    assert partnership["my_role"] == "owner"
    assert partnership["status"] == "pending"

    invite = await client.post(
        f"/partnerships/{partnership_id}/invitations",
        headers=seller_a["headers"],
        json={
            "invitee_seller_id": store_b["id"],
            "invited_role": "partner",
            "message": "Join our partnership",
            "expires_in_days": 7,
        },
    )
    assert invite.status_code == 201, invite.text
    invitation_id = invite.json()["id"]

    inbox = await client.get("/partnerships/me/invitations", headers=seller_b["headers"])
    assert inbox.status_code == 200
    assert len(inbox.json()) == 1

    accepted = await client.post(
        f"/partnerships/me/invitations/{invitation_id}/accept",
        headers=seller_b["headers"],
    )
    assert accepted.status_code == 204, accepted.text

    detail = await client.get(f"/partnerships/{partnership_id}", headers=seller_b["headers"])
    assert detail.status_code == 200
    assert len(detail.json()["members"]) == 2

    product = await _create_product(client, seller_a["headers"], store_a["id"])
    listing = await client.post(
        f"/partnerships/{partnership_id}/listings",
        headers=seller_a["headers"],
        json={
            "product_id": product["id"],
            "supplier_seller_id": store_a["id"],
            "fulfiller_seller_id": store_b["id"],
            "shared_inventory": True,
            "shared_pricing": True,
            "shared_stock_quantity": 5,
        },
    )
    assert listing.status_code == 201, listing.text

    # Partnership becomes active when invite is accepted
    public_before_activate = await client.get(f"/partnerships/public/product/{product['id']}")
    assert public_before_activate.status_code == 200
    assert public_before_activate.json() is not None

    activated = await client.patch(
        f"/partnerships/{partnership_id}",
        headers=seller_a["headers"],
        json={"status": "active"},
    )
    assert activated.status_code == 200, activated.text

    public2 = await client.get(f"/partnerships/public/product/{product['id']}")
    assert public2.status_code == 200
    body = public2.json()
    assert body is not None
    assert body["name"] == "Alpha Beta Alliance"
    assert len(body["members"]) == 2


@pytest.mark.asyncio
async def test_partnership_chat_and_analytics(client: AsyncClient):
    seller_a = await _register(client, "seller", "Chat A")
    seller_b = await _register(client, "seller", "Chat B")
    store_a = await _create_store(client, seller_a["headers"], "Chat Store A")
    store_b = await _create_store(client, seller_b["headers"], "Chat Store B")

    from datetime import UTC, datetime
    from sqlalchemy import update
    from app.database import SessionLocal
    from app.models import User

    async with SessionLocal() as session:
        await session.execute(
            update(User)
            .where(User.id.in_([seller_a["user_id"], seller_b["user_id"]]))
            .values(email_verified_at=datetime.now(UTC))
        )
        await session.commit()

    created = await client.post(
        "/partnerships",
        headers=seller_a["headers"],
        json={
            "name": "Chat Partners",
            "partnership_type": "long_term",
        },
    )
    assert created.status_code == 201
    pid = created.json()["id"]

    inv = await client.post(
        f"/partnerships/{pid}/invitations",
        headers=seller_a["headers"],
        json={"invitee_seller_id": store_b["id"]},
    )
    inv_id = inv.json()["id"]
    await client.post(f"/partnerships/me/invitations/{inv_id}/accept", headers=seller_b["headers"])
    await client.patch(f"/partnerships/{pid}", headers=seller_a["headers"], json={"status": "active"})

    msg = await client.post(
        f"/partnerships/{pid}/chat/messages",
        headers=seller_a["headers"],
        json={"body": "Hello partners"},
    )
    assert msg.status_code == 201, msg.text

    messages = await client.get(f"/partnerships/{pid}/chat/messages", headers=seller_b["headers"])
    assert messages.status_code == 200
    assert messages.json()[0]["body"] == "Hello partners"

    analytics = await client.get(f"/partnerships/{pid}/analytics", headers=seller_a["headers"])
    assert analytics.status_code == 200
    assert analytics.json()["chat_messages_count"] >= 1
