"""Manual platform advertisement campaign system tests."""

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.config import settings
from app.main import app
from app.models import PlatformAdCampaignStatus, PlatformAdPaymentStatus, PlatformAdvertisement, UserRole
from app.services.payment_provider import reset_payment_provider_cache
from tests.auth_helpers import register_test_user
from tests.seller_helpers import create_test_seller, seller_create_payload

pytestmark = pytest.mark.usefixtures("prepare_database")

SAMPLE_AD = {
    "advertiser_name": "Restaurant X",
    "campaign_name": "September Promotion",
    "title": "Summer sale",
    "description": "Great local deals",
    "image_url": "https://cdn.example.com/ads/summer.jpg",
    "target_url": "https://example.com/promo",
    "placement": "homepage_top",
    "status": "active",
    "payment_status": "paid",
    "priority": 5,
    "max_impressions": 10000,
    "max_impressions_per_user_per_day": 3,
}


@pytest.fixture(autouse=True)
def reset_provider_cache():
    reset_payment_provider_cache()
    yield
    reset_payment_provider_cache()


async def _admin_headers(client: AsyncClient) -> dict[str, str]:
    email = f"admin-{uuid4().hex[:8]}@example.com"
    body = await register_test_user(client, email=email)
    import app.database as database
    from app.models import User

    async with database.SessionLocal() as session:
        user = (await session.execute(select(User).where(User.email == email))).scalar_one()
        user.role = UserRole.ADMIN
        await session.commit()
    return {"Authorization": f"Bearer {body['access_token']}"}


async def _create_ad(client: AsyncClient, headers: dict[str, str], **overrides) -> dict:
    payload = {**SAMPLE_AD, **overrides}
    res = await client.post("/admin/advertisements", headers=headers, json=payload)
    assert res.status_code == 201, res.text
    return res.json()


@pytest.mark.asyncio
async def test_anonymous_user_sees_active_ads():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert public.status_code == 200
        ids = {row["id"] for row in public.json()}
        assert created["id"] in ids


@pytest.mark.asyncio
async def test_paused_campaign_not_displayed():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, status="paused")
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert public.status_code == 200
        assert all(row["id"] != created["id"] for row in public.json())


@pytest.mark.asyncio
async def test_unpaid_campaign_not_displayed_without_override():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, payment_status="pending", status="active")
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert public.status_code == 200
        assert all(row["id"] != created["id"] for row in public.json())


@pytest.mark.asyncio
async def test_placement_filtering():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        homepage = await _create_ad(client, headers, placement="homepage_top")
        await _create_ad(client, headers, placement="search_results", campaign_name="Search promo")
        public = await client.get("/ads/active", params={"placement": "search_results"})
        assert public.status_code == 200
        ids = {row["id"] for row in public.json()}
        assert homepage["id"] not in ids
        assert len(ids) == 1


@pytest.mark.asyncio
async def test_city_targeting():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        casablanca = await _create_ad(client, headers, target_city="casablanca")
        await _create_ad(client, headers, target_city="rabat", campaign_name="Rabat promo")
        matched = await client.get(
            "/ads/active",
            params={"placement": "homepage_top", "city": "casablanca"},
        )
        assert matched.status_code == 200
        assert len(matched.json()) == 1
        assert matched.json()[0]["id"] == casablanca["id"]


@pytest.mark.asyncio
async def test_impression_tracking_deduplicates_view_key():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, max_impressions=10)
        view_key = f"view-{uuid4().hex}"
        payload = {
            "campaign_id": created["id"],
            "placement": "homepage_top",
            "view_key": view_key,
        }
        first = await client.post("/ads/impressions", json=payload, headers={"X-Ad-Viewer": "viewer-1"})
        second = await client.post("/ads/impressions", json=payload, headers={"X-Ad-Viewer": "viewer-1"})
        assert first.status_code == 200
        assert second.status_code == 200
        assert first.json()["recorded"] is True
        assert second.json()["recorded"] is False

        detail = await client.get(f"/admin/advertisements/{created['id']}", headers=headers)
        assert detail.status_code == 200
        assert detail.json()["impression_count"] == 1


@pytest.mark.asyncio
async def test_click_tracking_redirects_safely():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=False) as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        click = await client.get(
            f"/ads/click/{created['id']}",
            params={"placement": "homepage_top", "click_key": f"click-{uuid4().hex}"},
            headers={"X-Ad-Viewer": "viewer-2"},
        )
        assert click.status_code == 302
        assert click.headers["location"] == "https://example.com/promo"
        detail = await client.get(f"/admin/advertisements/{created['id']}", headers=headers)
        assert detail.json()["click_count"] == 1


@pytest.mark.asyncio
async def test_campaign_expires_after_end_date():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        past = datetime.now(UTC) - timedelta(days=2)
        created = await _create_ad(
            client,
            headers,
            starts_at=(past - timedelta(days=1)).isoformat(),
            ends_at=past.isoformat(),
            status="active",
        )
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert all(row["id"] != created["id"] for row in public.json())
        detail = await client.get(f"/admin/advertisements/{created['id']}", headers=headers)
        assert detail.json()["status"] == "expired"


@pytest.mark.asyncio
async def test_non_admin_cannot_manage_advertisements():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        buyer = await register_test_user(client, email=f"not-admin-{uuid4().hex[:8]}@example.com")
        headers = {"Authorization": f"Bearer {buyer['access_token']}"}
        blocked = await client.post("/admin/advertisements", headers=headers, json=SAMPLE_AD)
        assert blocked.status_code == 403


@pytest.mark.asyncio
async def test_non_admin_cannot_record_fake_impressions_for_unpaid_campaign():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        admin_headers = await _admin_headers(client)
        created = await _create_ad(
            client,
            admin_headers,
            payment_status="pending",
            status="draft",
        )
        res = await client.post(
            "/ads/impressions",
            json={
                "campaign_id": created["id"],
                "placement": "homepage_top",
                "view_key": f"view-{uuid4().hex}",
            },
        )
        assert res.status_code == 200
        assert res.json()["recorded"] is False


@pytest.mark.asyncio
async def test_admin_rejects_unsafe_target_url():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        res = await client.post(
            "/admin/advertisements",
            headers=headers,
            json={**SAMPLE_AD, "target_url": "javascript:alert(1)"},
        )
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_admin_cannot_activate_unpaid_without_override():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers, status="draft", payment_status="pending")
        res = await client.patch(
            f"/admin/advertisements/{created['id']}",
            headers=headers,
            json={"status": "active"},
        )
        assert res.status_code == 400


@pytest.mark.asyncio
async def test_admin_overview_and_meta():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        await _create_ad(client, headers)
        meta = await client.get("/admin/advertisements/meta", headers=headers)
        overview = await client.get("/admin/advertisements/overview", headers=headers)
        assert meta.status_code == 200
        assert "homepage_top" in {item["value"] for item in meta.json()["placements"]}
        assert overview.status_code == 200
        assert overview.json()["active_campaigns"] >= 1


@pytest.mark.asyncio
async def test_ads_disabled_returns_empty_feed(monkeypatch):
    monkeypatch.setattr(settings, "ads_enabled", False)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        await _create_ad(client, headers)
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert public.status_code == 200
        assert public.json() == []


@pytest.mark.asyncio
async def test_soft_delete_hides_campaign():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        deleted = await client.delete(f"/admin/advertisements/{created['id']}", headers=headers)
        assert deleted.status_code == 204
        public = await client.get("/ads/active", params={"placement": "homepage_top"})
        assert all(row["id"] != created["id"] for row in public.json())


@pytest.mark.asyncio
async def test_click_rejected_for_paused_campaign():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test", follow_redirects=False) as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        await client.post(f"/admin/advertisements/{created['id']}/pause", headers=headers)
        click = await client.get(
            f"/ads/click/{created['id']}",
            params={"placement": "homepage_top", "click_key": f"click-{uuid4().hex}"},
        )
        assert click.status_code == 404
        detail = await client.get(f"/admin/advertisements/{created['id']}", headers=headers)
        assert detail.json()["click_count"] == 0


@pytest.mark.asyncio
async def test_invalid_placement_rejected():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        res = await client.post(
            "/admin/advertisements",
            headers=headers,
            json={**SAMPLE_AD, "placement": "nonexistent_slot"},
        )
        assert res.status_code == 422


@pytest.mark.asyncio
async def test_ad_media_proxy_requires_active_campaign():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        missing = await client.get(f"/ads/media/{uuid4()}/image")
        assert missing.status_code == 404

        paused = await client.post(f"/admin/advertisements/{created['id']}/pause", headers=headers)
        assert paused.status_code == 200
        blocked = await client.get(f"/ads/media/{created['id']}/image")
        assert blocked.status_code == 404


@pytest.mark.asyncio
async def test_ad_media_proxy_serves_external_image(monkeypatch):
    import httpx

    async def _fake_get(self, url, *args, **kwargs):
        request = httpx.Request("GET", url)
        return httpx.Response(
            200,
            headers={"content-type": "image/jpeg"},
            content=b"fake-image-bytes",
            request=request,
        )

    monkeypatch.setattr(httpx.AsyncClient, "get", _fake_get)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = await _admin_headers(client)
        created = await _create_ad(client, headers)
        served = await client.get(f"/ads/media/{created['id']}/image")
        assert served.status_code == 200
        assert served.headers["content-type"].startswith("image/")
        assert served.content == b"fake-image-bytes"
