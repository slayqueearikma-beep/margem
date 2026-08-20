"""Serve localized legal documents as static HTML."""

import json
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse

router = APIRouter(tags=["legal"])

_LEGAL_ROOT = Path(__file__).resolve().parents[2] / "static" / "legal"
_MANIFEST_PATH = _LEGAL_ROOT / "manifest.json"
_SUPPORTED = {"en", "fr", "ar"}


def _load_manifest() -> dict:
    if not _MANIFEST_PATH.is_file():
        return {"documents": []}
    return json.loads(_MANIFEST_PATH.read_text(encoding="utf-8"))


def _document_slugs() -> set[str]:
    manifest = _load_manifest()
    return {doc["slug"] for doc in manifest.get("documents", []) if doc.get("slug")}


def _pick_language(request: Request, explicit: str | None = None) -> str:
    if explicit and explicit in _SUPPORTED:
        return explicit
    accept = request.headers.get("accept-language", "")
    for part in accept.replace(" ", "").split(","):
        code = part.split(";")[0].split("-")[0].lower()
        if code in _SUPPORTED:
            return code
    return "en"


def _legal_file(lang: str, doc: str) -> Path:
    path = _LEGAL_ROOT / lang / f"{doc}.html"
    if not path.is_file():
        path = _LEGAL_ROOT / "en" / f"{doc}.html"
    return path


@router.get("/legal/manifest")
async def legal_manifest():
    """Public registry of served legal documents (stable ids, versions, titles)."""
    return JSONResponse(_load_manifest())


@router.api_route("/legal/{lang}/{doc}", methods=["GET", "HEAD"])
async def legal_document(lang: str, doc: str):
    docs = _document_slugs()
    if lang not in _SUPPORTED or doc not in docs:
        raise HTTPException(status_code=404, detail="Not found")
    path = _legal_file(lang, doc)
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Document not available")
    return FileResponse(path, media_type="text/html; charset=utf-8")


@router.get("/privacy")
async def privacy_redirect(request: Request, lang: str | None = None):
    code = _pick_language(request, lang)
    return RedirectResponse(url=f"/legal/{code}/privacy", status_code=302)


@router.get("/terms")
async def terms_redirect(request: Request, lang: str | None = None):
    code = _pick_language(request, lang)
    return RedirectResponse(url=f"/legal/{code}/terms", status_code=302)


@router.get("/cookies")
async def cookies_redirect(request: Request, lang: str | None = None):
    code = _pick_language(request, lang)
    return RedirectResponse(url=f"/legal/{code}/cookies", status_code=302)
