"""Bundle builder — multi-seller package resolution."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.data.bundle_templates import BUNDLE_TEMPLATES, BUNDLE_TEMPLATE_BY_SLUG
from app.database import get_db
from app.limiter import limiter
from app.schemas.bundle import BundleResolveIn, BundleResolveOut, BundleTemplateOut
from app.services.bundle_matcher import resolve_bundle
from app.services.marketplace_scope import resolve_marketplace_id

router = APIRouter(prefix="/bundles", tags=["bundles"])


@router.get("/templates", response_model=list[BundleTemplateOut])
async def list_bundle_templates(
    marketplace: str | None = Query(default=None, max_length=80),
) -> list[BundleTemplateOut]:
    templates = BUNDLE_TEMPLATES
    if marketplace:
        templates = [t for t in templates if t["marketplace_slug"] == marketplace]
    return [
        BundleTemplateOut(
            slug=item["slug"],
            name=item["name"],
            description=item["description"],
            icon=item["icon"],
            marketplace_slug=item["marketplace_slug"],
            slots=item["slots"],
        )
        for item in templates
    ]


@router.get("/templates/{slug}", response_model=BundleTemplateOut)
async def get_bundle_template(slug: str) -> BundleTemplateOut:
    item = BUNDLE_TEMPLATE_BY_SLUG.get(slug)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bundle template not found")
    return BundleTemplateOut(
        slug=item["slug"],
        name=item["name"],
        description=item["description"],
        icon=item["icon"],
        marketplace_slug=item["marketplace_slug"],
        slots=item["slots"],
    )


@router.post("/resolve", response_model=BundleResolveOut)
@limiter.limit("30/minute")
async def resolve_bundle_endpoint(
    request: Request,
    payload: BundleResolveIn,
    session: AsyncSession = Depends(get_db),
) -> BundleResolveOut:
    marketplace_id = await resolve_marketplace_id(session, payload.marketplace)
    if payload.template_slug and payload.template_slug not in BUNDLE_TEMPLATE_BY_SLUG:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bundle template not found")
    return await resolve_bundle(
        session,
        marketplace_slug=payload.marketplace,
        marketplace_id=marketplace_id,
        payload=payload,
    )
