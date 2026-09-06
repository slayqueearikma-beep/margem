"""Subscription catalog normalization tests."""

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import update

from app.main import app
from app.models import SubscriptionPlan


@pytest.mark.asyncio
async def test_list_plans_returns_authoritative_driver_pro_catalog(prepare_database):
    from app.database import SessionLocal

    async with SessionLocal() as session:
        await session.execute(
            update(SubscriptionPlan)
            .where(SubscriptionPlan.code == "seller_pro")
            .values(
                name="Dribex Pro",
                price_mad=99,
                description="Old plan copy",
                features=["Advanced analytics", "Unlimited coupons"],
            )
        )
        await session.commit()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/subscriptions/plans", params={"audience": "seller"})
        assert response.status_code == 200
        plans = response.json()
        assert len(plans) == 1
        plan = plans[0]
        assert plan["code"] == "seller_pro"
        assert plan["name"] == "DriverPro"
        assert float(plan["price_mad"]) == 149.0
        assert "video_uploads" in plan["features"]
        assert "Advanced analytics" not in plan["features"]
