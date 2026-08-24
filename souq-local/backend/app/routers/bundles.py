"""Bundle builder — DEPRECATED: retired from the active Dribex product.

Routes intentionally return HTTP 410 Gone. Supporting code in ``bundle_matcher.py``,
``schemas/bundle.py``, and ``data/bundle_templates.py`` is retained temporarily for a
later cleanup pass. Do not re-enable without an explicit product decision.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

router = APIRouter(prefix="/bundles", tags=["bundles"])

BUNDLE_RETIRED_DETAIL = "Bundle Builder is no longer available in Dribex."


def _bundle_retired() -> None:
    raise HTTPException(status_code=status.HTTP_410_GONE, detail=BUNDLE_RETIRED_DETAIL)


@router.get("/templates")
async def list_bundle_templates() -> None:
    _bundle_retired()


@router.get("/templates/{slug}")
async def get_bundle_template(slug: str) -> None:
    _bundle_retired()


@router.post("/resolve")
async def resolve_bundle_endpoint() -> None:
    _bundle_retired()
