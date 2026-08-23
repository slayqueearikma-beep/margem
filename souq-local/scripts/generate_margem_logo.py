#!/usr/bin/env python3
"""Generate high-quality MarGem logo PNG assets (supersampled anti-aliased)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "mobile" / "assets" / "images"
BRAND = ROOT / "brand"
ANDROID_RES = ROOT / "mobile" / "android" / "app" / "src" / "main" / "res"

# Official palette
LAVENDER = (154, 135, 246, 255)
PEACH = (246, 215, 182, 255)
OVERLAP = (154, 135, 246, 115)
HIGHLIGHT = (255, 255, 255, 72)
NAVY = (26, 29, 46, 255)
LAVENDER_TEXT = (154, 135, 246, 255)
LAUNCHER_BG = (248, 241, 233, 255)  # #F8F1E9 warm cream


def _draw_pills(draw: ImageDraw.ImageDraw, size: int) -> None:
    w = h = size

    left = [
        (w * 0.20, h * 0.90),
        (w * 0.10, h * 0.62),
        (w * 0.14, h * 0.22),
        (w * 0.30, h * 0.10),
        (w * 0.36, h * 0.38),
        (w * 0.40, h * 0.62),
        (w * 0.46, h * 0.90),
    ]
    right = [
        (w * 0.80, h * 0.90),
        (w * 0.90, h * 0.62),
        (w * 0.86, h * 0.22),
        (w * 0.70, h * 0.10),
        (w * 0.64, h * 0.38),
        (w * 0.60, h * 0.62),
        (w * 0.54, h * 0.90),
    ]
    center = [
        (w * 0.46, h * 0.90),
        (w * 0.48, h * 0.55),
        (w * 0.50, h * 0.30),
        (w * 0.50, h * 0.14),
        (w * 0.52, h * 0.30),
        (w * 0.52, h * 0.55),
        (w * 0.54, h * 0.90),
    ]

    draw.polygon(left, fill=LAVENDER)
    draw.polygon(right, fill=PEACH)
    draw.polygon(center, fill=OVERLAP)
    draw.polygon(center, fill=HIGHLIGHT)


def _render_icon(size: int, *, supersample: int = 4) -> Image.Image:
    big = size * supersample
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    _draw_pills(draw, big)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def _render_lockup(width: int = 1024, *, supersample: int = 4) -> Image.Image:
    icon_size = int(width * 0.52)
    icon = _render_icon(icon_size, supersample=supersample)
    canvas_h = int(width * 1.22)
    canvas = Image.new("RGBA", (width, canvas_h), (0, 0, 0, 0))
    x = (width - icon_size) // 2
    canvas.paste(icon, (x, 0), icon)

    # Wordmark rendered as simple shapes (app uses vector wordmark at runtime).
    draw = ImageDraw.Draw(canvas)
    y = icon_size + int(width * 0.06)
    mar_bbox = draw.textbbox((0, 0), "Mar")
    gem_bbox = draw.textbbox((0, 0), "Gem")
    # Use default font; real app renders vector wordmark.
    font_size = max(24, int(width * 0.09))
    try:
        from PIL import ImageFont

        font_bold = ImageFont.truetype("DejaVuSans-Bold.ttf", font_size)
    except OSError:
        font_bold = ImageFont.load_default()
    mar_w = draw.textlength("Mar", font=font_bold)
    gem_w = draw.textlength("Gem", font=font_bold)
    total = mar_w + gem_w
    start_x = (width - total) // 2
    draw.text((start_x, y), "Mar", fill=NAVY, font=font_bold)
    draw.text((start_x + mar_w, y), "Gem", fill=LAVENDER_TEXT, font=font_bold)
    return canvas


def _square_launcher(icon: Image.Image, size: int, *, scale: float = 0.72) -> Image.Image:
    """Logo centered on warm cream square — legacy launcher icon."""
    canvas = Image.new("RGBA", (size, size), LAUNCHER_BG)
    logo = icon.copy()
    logo.thumbnail((int(size * scale), int(size * scale)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def _adaptive_foreground(icon: Image.Image, size: int, *, scale: float = 0.58) -> Image.Image:
    """Transparent foreground for Android adaptive icon (safe zone)."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    logo = icon.copy()
    logo.thumbnail((int(size * scale), int(size * scale)), Image.Resampling.LANCZOS)
    canvas.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
    return canvas


def _generate_launcher_icons(icon_master: Image.Image) -> None:
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        out = ANDROID_RES / folder
        out.mkdir(parents=True, exist_ok=True)
        _square_launcher(icon_master, size).save(out / "ic_launcher.png", optimize=True)
        _adaptive_foreground(icon_master, size).save(
            out / "ic_launcher_foreground.png", optimize=True
        )

    # Splash drawable logo
    splash_dir = ANDROID_RES / "drawable"
    splash_dir.mkdir(parents=True, exist_ok=True)
    _square_launcher(icon_master, 400, scale=0.68).save(
        splash_dir / "splash_logo.png", optimize=True
    )


def _generate_store_icons(icon_master: Image.Image) -> None:
    for name, dim in [
        ("favicon-16.png", 16),
        ("favicon-32.png", 32),
        ("favicon-48.png", 48),
        ("apple-touch-icon.png", 180),
        ("icon-192.png", 192),
        ("icon-512.png", 512),
    ]:
        _square_launcher(icon_master, dim, scale=0.72).save(BRAND / name, optimize=True)

    ico_sizes = [16, 32, 48]
    ico_imgs = [_square_launcher(icon_master, s, scale=0.72) for s in ico_sizes]
    ico_imgs[0].save(BRAND / "favicon.ico", format="ICO", sizes=[(s, s) for s in ico_sizes])


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    BRAND.mkdir(parents=True, exist_ok=True)

    for name, size in [
        ("margem_logo.png", 1024),
        ("margem_logo@2x.png", 2048),
        ("margem_logo@3x.png", 3072),
    ]:
        _render_icon(size).save(ASSETS / name, optimize=True)

    for name, size in [
        ("margem_logo_full.png", 1024),
        ("margem_logo_full@2x.png", 1536),
    ]:
        _render_lockup(size).save(ASSETS / name, optimize=True)

    # Brand folder masters for CI / web
    icon_master = _render_icon(1024)
    icon_master.save(BRAND / "margem_logo_icon.png", optimize=True)
    _render_lockup(1024).save(BRAND / "margem_logo.png", optimize=True)

    _generate_launcher_icons(icon_master)
    _generate_store_icons(icon_master)

    print(f"Generated logo + launcher assets in {ASSETS}")


if __name__ == "__main__":
    main()
