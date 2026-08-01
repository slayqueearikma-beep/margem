#!/usr/bin/env python3
"""Regenerate MarGem brand assets from brand/margem_logo_master.png."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "brand" / "margem_logo_master.png"


def _square_icon(img: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo = img.copy()
    logo.thumbnail((int(size * 0.82), int(size * 0.82)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source logo: {SRC}")

    img = Image.open(SRC).convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    assets = ROOT / "mobile" / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)
    master = img.copy()
    master.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    master.save(assets / "margem_logo.png", optimize=True)

    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        out = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res" / folder
        out.mkdir(parents=True, exist_ok=True)
        _square_icon(img, size).save(out / "ic_launcher.png", optimize=True)

    splash_dir = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res" / "drawable"
    splash_dir.mkdir(parents=True, exist_ok=True)
    _square_icon(img, 400).save(splash_dir / "splash_logo.png", optimize=True)

    brand = ROOT / "brand"
    brand.mkdir(parents=True, exist_ok=True)
    for name, dim in [
        ("favicon-16.png", 16),
        ("favicon-32.png", 32),
        ("favicon-48.png", 48),
        ("apple-touch-icon.png", 180),
        ("icon-192.png", 192),
        ("icon-512.png", 512),
    ]:
        _square_icon(img, dim).save(brand / name, optimize=True)

    og = Image.new("RGBA", (1200, 630), (255, 255, 255, 255))
    logo = img.copy()
    logo.thumbnail((420, 420), Image.Resampling.LANCZOS)
    og.paste(logo, ((1200 - logo.width) // 2, (630 - logo.height) // 2), logo)
    og.save(brand / "og-image.png", optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [_square_icon(img, s) for s in ico_sizes]
    ico_imgs[0].save(brand / "favicon.ico", format="ICO", sizes=[(s, s) for s in ico_sizes])

    static = ROOT / "backend" / "static" / "brand"
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
        shutil.copy2(brand / name, static / name)
    master.save(static / "margem_logo.png", optimize=True)
    print("Brand assets regenerated.")


if __name__ == "__main__":
    main()
