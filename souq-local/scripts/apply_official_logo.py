#!/usr/bin/env python3
"""Apply the official MarGem terracotta skyline mark to all brand/mobile assets."""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "brand" / "margem_logo_official_source.png"
FALLBACK_SOURCE = Path(
    "/home/ubuntu/.cursor/projects/workspace/assets/772bc119-1bdf-418e-b2d7-d0cc4b2413a4.png"
)
BRAND = ROOT / "brand"
MOBILE_ASSETS = ROOT / "mobile" / "assets" / "images"
CREAM = (248, 241, 233, 255)


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


def fit_on_cream(im: Image.Image, width: int) -> Image.Image:
    fitted = im.copy()
    fitted.thumbnail((width, width * 2), Image.Resampling.LANCZOS)
    height = max(int(width * fitted.height / max(fitted.width, 1)), width // 2)
    canvas = Image.new("RGBA", (width, height), CREAM)
    canvas.paste(
        fitted,
        ((width - fitted.width) // 2, (height - fitted.height) // 2),
        fitted,
    )
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


def export_mobile_assets(mark: Image.Image) -> None:
    MOBILE_ASSETS.mkdir(parents=True, exist_ok=True)
    for size, name in (
        (512, "margem_logo.png"),
        (1024, "margem_logo@2x.png"),
        (1536, "margem_logo@3x.png"),
    ):
        square_icon(mark, size, scale=0.92).save(MOBILE_ASSETS / name, optimize=True)

    full = fit_on_cream(mark, 1024)
    full.save(MOBILE_ASSETS / "margem_logo_full.png", optimize=True)
    full.resize((1536, int(1536 * full.height / full.width)), Image.Resampling.LANCZOS).save(
        MOBILE_ASSETS / "margem_logo_full@2x.png", optimize=True
    )
    full.resize((2048, int(2048 * full.height / full.width)), Image.Resampling.LANCZOS).save(
        MOBILE_ASSETS / "margem_logo_full@3x.png", optimize=True
    )


def export_brand_assets(mark: Image.Image, full: Image.Image) -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    square_icon(mark, 1024, scale=0.92).save(BRAND / "margem_logo_icon.png", optimize=True)
    full.save(BRAND / "margem_logo.png", optimize=True)

    for name, dim in (
        ("favicon-16.png", 16),
        ("favicon-32.png", 32),
        ("favicon-48.png", 48),
        ("apple-touch-icon.png", 180),
        ("icon-192.png", 192),
        ("icon-512.png", 512),
    ):
        square_icon(mark, dim, scale=0.88).save(BRAND / name, optimize=True)

    og = Image.new("RGBA", (1200, 630), CREAM)
    og_logo = fit_on_cream(mark, 420)
    og.paste(og_logo, ((1200 - og_logo.width) // 2, (630 - og_logo.height) // 2), og_logo)
    og.save(BRAND / "og-image.png", optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [square_icon(mark, s, scale=0.88) for s in ico_sizes]
    ico_imgs[0].save(BRAND / "favicon.ico", format="ICO", sizes=[(s, s) for s in ico_sizes])


def export_android_assets(mark: Image.Image) -> None:
    res = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res"
    if not res.exists():
        return

    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        out = res / folder
        out.mkdir(parents=True, exist_ok=True)
        square_icon(mark, size, scale=0.88).save(out / "ic_launcher.png", optimize=True)
        square_icon(mark, size, scale=0.72).save(out / "ic_launcher_foreground.png", optimize=True)

    splash_dir = res / "drawable"
    splash_dir.mkdir(parents=True, exist_ok=True)
    square_icon(mark, 400, scale=0.92).save(splash_dir / "splash_logo.png", optimize=True)


def export_backend_static(mark: Image.Image, full: Image.Image) -> None:
    static = ROOT / "backend" / "static" / "brand"
    if not static.parent.exists():
        return

    static.mkdir(parents=True, exist_ok=True)
    for name in (
        "favicon.ico",
        "favicon-16.png",
        "favicon-32.png",
        "favicon-48.png",
        "apple-touch-icon.png",
        "icon-192.png",
        "icon-512.png",
        "og-image.png",
    ):
        shutil.copy2(BRAND / name, static / name)

    manifest = BRAND / "site.webmanifest"
    if manifest.exists():
        shutil.copy2(manifest, static / "site.webmanifest")

    square_icon(mark, 1024, scale=0.92).save(static / "margem_logo.png", optimize=True)
    full.save(static / "margem_logo_full.png", optimize=True)


def main() -> None:
    requested = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    source = resolve_source(requested)

    BRAND.mkdir(parents=True, exist_ok=True)
    source_copy = BRAND / "margem_logo_official_source.png"
    if source != source_copy:
        shutil.copy2(source, source_copy)
    source = source_copy

    transparent = strip_black_background(Image.open(source))
    mark = trim_and_square(transparent)
    full = fit_on_cream(mark, 1024)

    export_mobile_assets(mark)
    export_brand_assets(mark, full)
    export_android_assets(mark)
    export_backend_static(mark, full)
    print(f"Applied official logo from {source}")


if __name__ == "__main__":
    main()
