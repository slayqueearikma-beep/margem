#!/usr/bin/env python3
"""Regenerate MarGem brand assets from brand source PNGs."""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_ICON = ROOT / "brand" / "margem_logo_master.png"
SRC_FULL = ROOT / "brand" / "margem_logo_full.png"
FULL_ASPECT = 1536 / 1024  # height / width


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


def _fit_full_lockup(img: Image.Image, width: int) -> Image.Image:
    """Scale the vertical lockup to a target width, preserving aspect ratio."""
    height = int(width * FULL_ASPECT)
    fitted = img.copy()
    fitted.thumbnail((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    canvas.paste(
        fitted,
        ((width - fitted.width) // 2, (height - fitted.height) // 2),
        fitted,
    )
    return canvas


def _adaptive_foreground(img: Image.Image, size: int) -> Image.Image:
    """Android adaptive icon foreground (108dp safe zone)."""
    return _square_icon(img, size, scale=0.62)


def main() -> None:
    if not SRC_ICON.exists():
        raise SystemExit(f"Missing icon source: {SRC_ICON}")
    if not SRC_FULL.exists():
        raise SystemExit(f"Missing full lockup source: {SRC_FULL}")

    icon = _trim_logo(Image.open(SRC_ICON).convert("RGBA"))
    full = Image.open(SRC_FULL).convert("RGBA")

    assets = ROOT / "mobile" / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)

    icon_master = icon.copy()
    icon_master.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
    icon_master.save(assets / "margem_logo.png", optimize=True)

    full_master = _fit_full_lockup(full, 1024)
    full_master.save(assets / "margem_logo_full.png", optimize=True)

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
        _square_icon(icon, size).save(out / "ic_launcher.png", optimize=True)
        _adaptive_foreground(icon, size).save(out / "ic_launcher_foreground.png", optimize=True)

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
    _fit_full_lockup(full, 400).save(splash_dir / "splash_logo.png", optimize=True)

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
        _square_icon(icon, dim).save(brand / name, optimize=True)

    og = Image.new("RGBA", (1200, 630), (255, 255, 255, 255))
    og_logo = _fit_full_lockup(full, 420)
    og.paste(og_logo, ((1200 - og_logo.width) // 2, (630 - og_logo.height) // 2), og_logo)
    og.save(brand / "og-image.png", optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [_square_icon(icon, s) for s in ico_sizes]
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
    icon_master.save(static / "margem_logo.png", optimize=True)
    full_master.save(static / "margem_logo_full.png", optimize=True)
    print("Brand assets regenerated.")


if __name__ == "__main__":
    main()
