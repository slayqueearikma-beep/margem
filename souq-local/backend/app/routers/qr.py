"""Public QR / share-link resolution — HTTPS-only public identifiers."""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.limiter import limiter
from app.services.share_links import resolve_share_token

router = APIRouter(tags=["qr"])


@router.get("/p/{token}")
@limiter.limit("120/minute")
async def resolve_public_share(
    request: Request,
    token: str,
    session: AsyncSession = Depends(get_db),
) -> dict:
    """Resolve an opaque share token to public listing/seller metadata."""
    payload = await resolve_share_token(session, token)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return payload


@router.get("/qr/health")
@limiter.exempt
async def qr_health() -> dict:
    return {"status": "ok", "service": "qr"}
