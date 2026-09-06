#!/usr/bin/env python3
"""Regenerate Dribex brand assets from brand source PNGs.

Sources:
  brand/margem_logo.png       — full lockup (icon + wordmark + tagline)
  brand/margem_logo_icon.png  — optional app-icon tile for launcher/favicons only

In-app assets (mobile/assets/images/margem_logo*.png) always use a transparent
mark extracted from the lockup. If margem_logo_icon.png contains a baked purple
app-icon background, it is skipped for in-app use automatically.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_FULL = ROOT / "brand" / "margem_logo.png"
SRC_ICON = ROOT / "brand" / "margem_logo_icon.png"
WHITE_THRESHOLD = 245
# App-icon purple fill baked into margem_logo_icon.png (not for in-app headers).
_APP_ICON_PURPLE = ((32, 16, 80), (48, 16, 80), (32, 16, 64))


def _is_background_pixel(r: int, g: int, b: int) -> bool:
    return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD


def _is_app_icon_background_pixel(r: int, g: int, b: int) -> bool:
    if _is_background_pixel(r, g, b):
        return True
    for pr, pg, pb in _APP_ICON_PURPLE:
        if abs(r - pr) <= 20 and abs(g - pg) <= 12 and abs(b - pb) <= 20:
            return True
    return False


def _has_baked_app_icon_background(img: Image.Image, *, min_ratio: float = 0.12) -> bool:
    """True when the PNG is an app-icon tile (purple rounded square), not a transparent mark."""
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    total = width * height
    if total == 0:
        return False
    purple = 0
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 128 and _is_app_icon_background_pixel(r, g, b) and not _is_background_pixel(r, g, b):
                purple += 1
    return (purple / total) >= min_ratio


def _content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    rgb = img.convert("RGB")
    pixels = rgb.load()
    width, height = rgb.size
    min_x, min_y, max_x, max_y = width, height, 0, 0
    found = False
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y]
            if not _is_background_pixel(r, g, b):
                found = True
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)
    if not found:
        return (0, 0, width, height)
    return (min_x, min_y, max_x + 1, max_y + 1)


def _trim_margins(img: Image.Image, *, padding: int = 24) -> Image.Image:
    left, top, right, bottom = _content_bbox(img)
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img.width, right + padding)
    bottom = min(img.height, bottom + padding)
    return img.crop((left, top, right, bottom))


def _strip_white_background(img: Image.Image) -> Image.Image:
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, _ = pixels[x, y]
            if _is_background_pixel(r, g, b):
                pixels[x, y] = (255, 255, 255, 0)
    return rgba


def _extract_icon_from_lockup(full: Image.Image) -> Image.Image:
    """Fallback: crop the pin from the top of the vertical lockup."""
    width, height = full.size
    top = full.crop((0, 0, width, int(height * 0.56)))
    return _strip_white_background(top.crop(_content_bbox(top)))


def _load_transparent_mark(full: Image.Image) -> Image.Image:
    """In-app logo: transparent mark only (navbar, login, splash).

    Never use margem_logo_icon.png when it is an Android/iOS app-icon tile with a
    baked purple background — that produces the opaque square seen in headers.
    """
    if SRC_ICON.exists():
        candidate = Image.open(SRC_ICON).convert("RGBA")
        candidate = _trim_margins(candidate, padding=8)
        if not _has_baked_app_icon_background(candidate):
            pixels = candidate.load()
            for y in range(candidate.height):
                for x in range(candidate.width):
                    r, g, b, a = pixels[x, y]
                    if a > 0 and _is_background_pixel(r, g, b):
                        pixels[x, y] = (255, 255, 255, 0)
            return candidate
        print(
            "Note: margem_logo_icon.png is an app-icon tile (opaque background); "
            "using transparent mark extracted from margem_logo.png lockup instead."
        )
    return _extract_icon_from_lockup(full)


def _load_launcher_icon(full: Image.Image) -> Image.Image:
    """Launcher / favicon: may keep the app-icon purple tile when available."""
    if SRC_ICON.exists():
        icon = Image.open(SRC_ICON).convert("RGBA")
        pixels = icon.load()
        for y in range(icon.height):
            for x in range(icon.width):
                r, g, b, a = pixels[x, y]
                if a > 0 and _is_background_pixel(r, g, b):
                    pixels[x, y] = (255, 255, 255, 0)
        return _trim_margins(icon, padding=8)
    return _load_transparent_mark(full)


def _square_icon(img: Image.Image, size: int, *, scale: float = 0.88) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo = img.copy()
    logo.thumbnail((int(size * scale), int(size * scale)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def _fit_lockup(img: Image.Image, width: int) -> Image.Image:
    fitted = img.copy()
    fitted.thumbnail((width, width * 2), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, int(width * fitted.height / max(fitted.width, 1))), (255, 255, 255, 255))
    canvas.paste(
        fitted,
        ((width - fitted.width) // 2, (canvas.height - fitted.height) // 2),
        fitted.convert("RGBA"),
    )
    return canvas


def _adaptive_foreground(img: Image.Image, size: int) -> Image.Image:
    return _square_icon(img, size, scale=0.72)


def main() -> None:
    if not SRC_FULL.exists():
        raise SystemExit(
            f"Missing full lockup source: {SRC_FULL}\n"
            "Place your full Dribex lockup at souq-local/brand/margem_logo.png"
        )

    full = _trim_margins(Image.open(SRC_FULL).convert("RGB"))
    mark = _load_transparent_mark(full)
    launcher = _load_launcher_icon(full)

    assets = ROOT / "mobile" / "assets" / "images"
    assets.mkdir(parents=True, exist_ok=True)

    _square_icon(mark, 512, scale=0.92).save(assets / "margem_logo.png", optimize=True)
    _square_icon(mark, 1024, scale=0.92).save(assets / "margem_logo@2x.png", optimize=True)
    _square_icon(mark, 1536, scale=0.92).save(assets / "margem_logo@3x.png", optimize=True)

    full_master = _fit_lockup(full.convert("RGBA"), 1024)
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
        _square_icon(launcher, size).save(out / "ic_launcher.png", optimize=True)
        _adaptive_foreground(launcher, size).save(out / "ic_launcher_foreground.png", optimize=True)

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
    (values_dir / "colors.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F8F1E9</color>
    <color name="splash_background">#F8F1E9</color>
</resources>
""",
        encoding="utf-8",
    )

    splash_dir = res / "drawable"
    splash_dir.mkdir(parents=True, exist_ok=True)
    _square_icon(mark, 400).save(splash_dir / "splash_logo.png", optimize=True)

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
        _square_icon(launcher, dim).save(brand / name, optimize=True)

    og = Image.new("RGBA", (1200, 630), (255, 255, 255, 255))
    og_logo = _fit_lockup(full.convert("RGBA"), 420)
    og.paste(og_logo, ((1200 - og_logo.width) // 2, (630 - og_logo.height) // 2), og_logo)
    og.save(brand / "og-image.png", optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [_square_icon(launcher, s) for s in ico_sizes]
    ico_imgs[0].save(brand / "favicon.ico", format="ICO", sizes=[(s, s) for s in ico_sizes])

    manifest = brand / "site.webmanifest"
    manifest.write_text(
        """{
  "name": "Dribex",
  "short_name": "Dribex",
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
    mark_master = _square_icon(mark, 1024, scale=0.92)
    mark_master.save(static / "margem_logo.png", optimize=True)
    full_master.save(static / "margem_logo_full.png", optimize=True)
    mark_source = (
        "margem_logo_icon.png"
        if SRC_ICON.exists() and not _has_baked_app_icon_background(Image.open(SRC_ICON))
        else "margem_logo.png lockup (transparent mark)"
    )
    print(f"Brand assets regenerated (in-app mark from {mark_source}).")


if __name__ == "__main__":
    main()
