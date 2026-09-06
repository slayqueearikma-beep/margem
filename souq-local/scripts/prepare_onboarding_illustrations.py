#!/usr/bin/env python3
"""Bake MarGem cream (#F8F1E9) into onboarding illustration backgrounds.

Removes exported checkerboard / neutral gray PNG backgrounds while preserving
illustration artwork (edge-connected flood fill from image borders).
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ONBOARDING_DIR = ROOT / "mobile" / "assets" / "images" / "onboarding"
TARGET = (248, 241, 233)  # AppColors.cream / #F8F1E9


def _is_neutral_background(r: int, g: int, b: int) -> bool:
    spread = max(r, g, b) - min(r, g, b)
    if spread > 22:
        return False
    return min(r, g, b) >= 215


def _flood_background_mask(im: Image.Image) -> list[list[bool]]:
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    mask = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []

    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))

    seen: set[tuple[int, int]] = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or x < 0 or y < 0 or x >= w or y >= h:
            continue
        seen.add((x, y))
        r, g, b = px[x, y]
        if not _is_neutral_background(r, g, b):
            continue
        mask[y][x] = True
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    return mask


def _feather_boundary(rgb: Image.Image, mask: list[list[bool]]) -> None:
    w, h = rgb.size
    px = rgb.load()
    tr, tg, tb = TARGET

    for x in range(w):
        for y in range(h):
            if mask[y][x]:
                continue
            neighbors = 0
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and mask[ny][nx]:
                    neighbors += 1
            if neighbors == 0:
                continue
            r, g, b = px[x, y]
            spread = max(r, g, b) - min(r, g, b)
            if spread > 45 or min(r, g, b) < 170:
                continue
            px[x, y] = (
                int(r * 0.72 + tr * 0.28),
                int(g * 0.72 + tg * 0.28),
                int(b * 0.72 + tb * 0.28),
            )


def process_image(path: Path) -> None:
    im = Image.open(path)
    mask = _flood_background_mask(im)
    out = im.convert("RGB")
    px = out.load()
    w, h = out.size
    tr, tg, tb = TARGET

    replaced = 0
    for x in range(w):
        for y in range(h):
            if mask[y][x]:
                px[x, y] = TARGET
                replaced += 1

    _feather_boundary(out, mask)
    out.save(path, optimize=True)
    print(f"{path.name}: replaced {replaced:,} px ({100 * replaced / (w * h):.1f}%)")


def main() -> None:
    if not ONBOARDING_DIR.is_dir():
        raise SystemExit(f"Missing directory: {ONBOARDING_DIR}")

    for path in sorted(ONBOARDING_DIR.glob("*.png")):
        process_image(path)

    print("Onboarding illustrations updated.")


if __name__ == "__main__":
    main()
