#!/usr/bin/env python3
"""Apply the official MarGem terracotta skyline mark to app logo assets."""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "brand" / "margem_logo_official_source.png"
FALLBACK_SOURCE = Path(
    "/home/ubuntu/.cursor/projects/workspace/assets/772bc119-1bdf-418e-b2d7-d0cc4b2413a4.png"
)
MOBILE_ASSETS = ROOT / "mobile" / "assets" / "images"


def _is_black_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    return max(r, g, b) < 48 and max(r, g, b) - min(r, g, b) < 18


def strip_black_background(im: Image.Image) -> Image.Image:
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    visited: set[tuple[int, int]] = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]

    while stack:
        x, y = stack.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= w or y >= h:
            continue
        visited.add((x, y))
        r, g, b, a = px[x, y]
        if not _is_black_background(r, g, b, a):
            continue
        px[x, y] = (r, g, b, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    return rgba


def trim_and_square(im: Image.Image, *, pad_ratio: float = 0.06) -> Image.Image:
    alpha = im.getchannel("A").point(lambda value: 255 if value > 8 else 0)
    bbox = alpha.getbbox()
    if not bbox:
        return im

    c0, r0, c1, r1 = bbox
    pad = int(max(c1 - c0 + 1, r1 - r0 + 1) * pad_ratio)
    c0 = max(0, c0 - pad)
    r0 = max(0, r0 - pad)
    c1 = min(im.width - 1, c1 + pad)
    r1 = min(im.height - 1, r1 + pad)
    cropped = im.crop((c0, r0, c1 + 1, r1 + 1))

    cw, ch = cropped.size
    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
    return square


def square_icon(im: Image.Image, size: int, *, scale: float = 0.92) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo = im.copy()
    logo.thumbnail((int(size * scale), int(size * scale)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def resolve_source(path: Path | None) -> Path:
    if path and path.exists():
        return path
    if DEFAULT_SOURCE.exists():
        return DEFAULT_SOURCE
    if FALLBACK_SOURCE.exists():
        return FALLBACK_SOURCE
    raise SystemExit(
        "Missing official logo source. Place PNG at "
        f"{DEFAULT_SOURCE} or pass a path argument."
    )


def main() -> None:
    requested = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    source = resolve_source(requested)

    brand_dir = ROOT / "brand"
    brand_dir.mkdir(parents=True, exist_ok=True)
    if source != DEFAULT_SOURCE:
        source_copy = brand_dir / "margem_logo_official_source.png"
        if not source_copy.exists() or source.stat().st_mtime > source_copy.stat().st_mtime:
            Image.open(source).save(source_copy)
        source = source_copy

    mark = trim_and_square(strip_black_background(Image.open(source)))
    MOBILE_ASSETS.mkdir(parents=True, exist_ok=True)

    for size, name in (
        (512, "margem_logo.png"),
        (1024, "margem_logo@2x.png"),
        (1536, "margem_logo@3x.png"),
    ):
        square_icon(mark, size, scale=0.92).save(MOBILE_ASSETS / name, optimize=True)

    square_icon(mark, 1024, scale=0.92).save(brand_dir / "margem_logo_icon.png", optimize=True)
    print(f"Applied official logo from {source}")


if __name__ == "__main__":
    main()
