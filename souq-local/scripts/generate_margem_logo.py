#!/usr/bin/env python3
"""Generate high-quality MarGem logo PNG assets (supersampled anti-aliased)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "mobile" / "assets" / "images"
BRAND = ROOT / "brand"

# Official palette
LAVENDER = (154, 135, 246, 255)
PEACH = (246, 215, 182, 255)
OVERLAP = (154, 135, 246, 115)
HIGHLIGHT = (255, 255, 255, 72)
NAVY = (26, 29, 46, 255)
LAVENDER_TEXT = (154, 135, 246, 255)


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
    _render_icon(512).save(BRAND / "margem_logo_icon.png", optimize=True)
    _render_lockup(1024).save(BRAND / "margem_logo.png", optimize=True)

    print(f"Generated high-quality logo assets in {ASSETS}")


if __name__ == "__main__":
    main()
