#!/usr/bin/env python3
"""Prepare official MarGem ribbon-M logo PNGs for Flutter (transparent, trimmed)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MOBILE_ASSETS = ROOT / "mobile" / "assets" / "images"
BRAND_ICON = ROOT / "brand" / "margem_logo_icon.png"


def _is_background(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return True
    return r > 230 and g > 230 and b > 230 and max(r, g, b) - min(r, g, b) < 12


def trim_and_square(src: Path, dst: Path, pad_ratio: float = 0.04) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()
    visited: set[tuple[int, int]] = set()
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]

    while stack:
        x, y = stack.pop()
        if (x, y) in visited or x < 0 or y < 0 or x >= w or y >= h:
            continue
        visited.add((x, y))
        r, g, b, a = px[x, y]
        if not _is_background(r, g, b, a):
            continue
        px[x, y] = (r, g, b, 0)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    alpha = im.getchannel("A").point(lambda value: 255 if value > 8 else 0)
    bbox = alpha.getbbox()
    if not bbox:
        im.save(dst, optimize=True)
        return im

    c0, r0, c1, r1 = bbox
    pad = int(max(c1 - c0 + 1, r1 - r0 + 1) * pad_ratio)
    c0 = max(0, c0 - pad)
    r0 = max(0, r0 - pad)
    c1 = min(w - 1, c1 + pad)
    r1 = min(h - 1, r1 + pad)
    cropped = im.crop((c0, r0, c1 + 1, r1 + 1))

    cw, ch = cropped.size
    side = max(cw, ch)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cropped, ((side - cw) // 2, (side - ch) // 2), cropped)
    square.save(dst, optimize=True)
    return square


def export_sizes(master: Image.Image) -> None:
    for size, name in (
        (512, "margem_logo.png"),
        (1024, "margem_logo@2x.png"),
        (1536, "margem_logo@3x.png"),
    ):
        resized = master.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(MOBILE_ASSETS / name, optimize=True)


def main() -> None:
    source = MOBILE_ASSETS / "margem_logo@3x.png"
    if not source.exists():
        raise SystemExit(f"Missing source asset: {source}")

    trimmed = trim_and_square(source, MOBILE_ASSETS / "_margem_logo_trimmed.png")
    export_sizes(trimmed)
    trimmed.resize((512, 512), Image.Resampling.LANCZOS).save(BRAND_ICON, optimize=True)
    (MOBILE_ASSETS / "_margem_logo_trimmed.png").unlink(missing_ok=True)
    print("Updated mobile logo assets and brand icon.")


if __name__ == "__main__":
    main()
