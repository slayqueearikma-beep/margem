#!/usr/bin/env python3
"""Regenerate MarGem brand assets from brand/margem_logo_master.png."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "brand" / "margem_logo_master.png"
BRAND_RED = (114, 16, 25, 255)  # #721019


def _trim_logo(img: Image.Image) -> Image.Image:
    """Crop transparent padding and drop the soft ground shadow."""
    bbox = img.getbbox()
    if not bbox:
        return img
    cropped = img.crop(bbox)
    width, height = cropped.size
    # Shadow sits in the bottom ~10%; launcher icons look cleaner without it.
    return cropped.crop((0, 0, width, int(height * 0.9)))


def _square_icon(img: Image.Image, size: int, *, scale: float = 0.78) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo = img.copy()
    logo.thumbnail((int(size * scale), int(size * scale)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def _adaptive_foreground(img: Image.Image, size: int) -> Image.Image:
    """Android adaptive icon foreground (108dp safe zone)."""
    return _square_icon(img, size, scale=0.62)


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"Missing source logo: {SRC}")

    img = _trim_logo(Image.open(SRC).convert("RGBA"))

    assets = ROOT / "mobile" / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)
    master = img.copy()
    master.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    master.save(assets / "margem_logo.png", optimize=True)

    res = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res"
    for folder, size in {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }.items():
        out = res / folder
        out.mkdir(parents=True, exist_ok=True)
        _square_icon(img, size).save(out / "ic_launcher.png", optimize=True)
        _adaptive_foreground(img, size).save(out / "ic_launcher_foreground.png", optimize=True)

    adaptive_dir = res / "mipmap-anydpi-v26"
    adaptive_dir.mkdir(parents=True, exist_ok=True)
    (adaptive_dir / "ic_launcher.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""",
        encoding="utf-8",
    )

    values_dir = res / "values"
    values_dir.mkdir(parents=True, exist_ok=True)
    colors_path = values_dir / "colors.xml"
    colors_path.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
""",
        encoding="utf-8",
    )

    splash_dir = res / "drawable"
    splash_dir.mkdir(parents=True, exist_ok=True)
    _square_icon(img, 400, scale=0.72).save(splash_dir / "splash_logo.png", optimize=True)

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
    logo.thumbnail((360, 360), Image.Resampling.LANCZOS)
    og.paste(logo, ((1200 - logo.width) // 2, (630 - logo.height) // 2 - 20), logo)
    og.save(brand / "og-image.png", optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [_square_icon(img, s) for s in ico_sizes]
    ico_imgs[0].save(brand / "favicon.ico", format="ICO", sizes=[(s, s) for s in ico_sizes])

    manifest = brand / "site.webmanifest"
    manifest.write_text(
        """{
  "name": "MarGem",
  "short_name": "MarGem",
  "description": "Discover Morocco's hidden gems",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#721019",
  "icons": [
    {
      "src": "/brand/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/brand/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
""",
        encoding="utf-8",
    )

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
        "site.webmanifest",
    ):
        shutil.copy2(brand / name, static / name)
    master.save(static / "margem_logo.png", optimize=True)
    print("Brand assets regenerated.")


if __name__ == "__main__":
    main()
