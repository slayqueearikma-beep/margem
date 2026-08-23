#!/usr/bin/env python3
"""Generate MarGem M-logo PNG assets for the mobile app."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "mobile" / "assets" / "images"

LAVENDER = (155, 138, 251, 235)
PEACH = (255, 160, 122, 235)
OVERLAP = (255, 255, 255, 115)
NAVY = (26, 29, 46, 255)


def _draw_m(draw: ImageDraw.ImageDraw, size: int) -> None:
    w = h = size
    cx = w / 2

    left = [
        (cx - w * 0.38, h * 0.88),
        (cx - w * 0.42, h * 0.55),
        (cx - w * 0.30, h * 0.12),
        (cx - w * 0.22, h * 0.42),
        (cx - w * 0.08, h * 0.88),
    ]
    right = [
        (cx + w * 0.38, h * 0.88),
        (cx + w * 0.42, h * 0.55),
        (cx + w * 0.30, h * 0.12),
        (cx + w * 0.22, h * 0.42),
        (cx + w * 0.08, h * 0.88),
    ]
    overlap = [
        (cx - w * 0.08, h * 0.88),
        (cx, h * 0.50),
        (cx + w * 0.08, h * 0.88),
    ]

    draw.polygon(left, fill=LAVENDER)
    draw.polygon(right, fill=PEACH)
    draw.polygon(overlap, fill=OVERLAP)


def _icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")
    _draw_m(draw, size)
    return img


def _full_lockup(width: int = 512) -> Image.Image:
    icon_h = int(width * 0.55)
    icon = _icon(icon_h)
    canvas_h = int(width * 1.35)
    canvas = Image.new("RGBA", (width, canvas_h), (255, 255, 255, 0))
    canvas.paste(icon, ((width - icon_h) // 2, 0), icon)

    # Simple wordmark placeholder — app uses vector wordmark at runtime.
    draw = ImageDraw.Draw(canvas)
    text_y = icon_h + int(width * 0.08)
    mar_x = int(width * 0.22)
    draw.text((mar_x, text_y), "Mar", fill=NAVY)
    gem_x = mar_x + int(width * 0.18)
    draw.text((gem_x, text_y), "Gem", fill=LAVENDER)
    return canvas


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    _icon(1024).save(ASSETS / "margem_logo.png", optimize=True)
    _full_lockup(1024).save(ASSETS / "margem_logo_full.png", optimize=True)
    print(f"Generated logo assets in {ASSETS}")


if __name__ == "__main__":
    main()
