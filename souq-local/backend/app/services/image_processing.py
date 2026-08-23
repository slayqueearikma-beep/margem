"""Safe image normalization for user-uploaded photographs (no biometric processing)."""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass

from PIL import Image, UnidentifiedImageError

logger = logging.getLogger("margem.storage")

MAX_IMAGE_BYTES = 8_388_608
MAX_IMAGE_PIXELS = 16_000_000  # ~16 MP decompression guard
MAX_IMAGE_DIMENSION = 4096
PROFILE_OUTPUT_MAX_DIMENSION = 1024


@dataclass(frozen=True)
class SanitizedImage:
    data: bytes
    content_type: str
    width: int
    height: int


def _output_format(content_type: str) -> tuple[str, str]:
    if content_type == "image/png":
        return "PNG", "image/png"
    if content_type == "image/webp":
        return "WEBP", "image/webp"
    # Normalize GIF and JPEG derivatives to JPEG for public profile photos.
    return "JPEG", "image/jpeg"


def sanitize_image_bytes(
    data: bytes,
    *,
    content_type: str,
    max_dimension: int = MAX_IMAGE_DIMENSION,
) -> SanitizedImage:
    """Decode, bound dimensions/pixels, strip metadata, and re-encode safely."""
    if not data:
        raise ValueError("Empty image upload")
    if len(data) > MAX_IMAGE_BYTES:
        raise ValueError("Image too large")

    Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS
    try:
        with Image.open(io.BytesIO(data)) as img:
            img.load()
            width, height = img.size
            if width < 1 or height < 1:
                raise ValueError("Invalid image dimensions")
            if width > max_dimension or height > max_dimension:
                raise ValueError("Image dimensions exceed allowed maximum")
            if width * height > MAX_IMAGE_PIXELS:
                raise ValueError("Image pixel count exceeds allowed maximum")

            if img.mode in {"RGBA", "LA", "P"} and content_type == "image/jpeg":
                converted = img.convert("RGB")
            elif img.mode not in {"RGB", "RGBA", "L"}:
                converted = img.convert("RGB")
            else:
                converted = img.copy()

            fmt, out_type = _output_format(content_type)
            buffer = io.BytesIO()
            save_kwargs: dict = {}
            if fmt == "JPEG":
                save_kwargs["quality"] = 85
                save_kwargs["optimize"] = True
            converted.save(buffer, format=fmt, **save_kwargs)
            out = buffer.getvalue()
            if len(out) > MAX_IMAGE_BYTES:
                raise ValueError("Processed image exceeds size limit")
            return SanitizedImage(
                data=out,
                content_type=out_type,
                width=converted.width,
                height=converted.height,
            )
    except UnidentifiedImageError as exc:
        raise ValueError("Uploaded file is not a valid image") from exc
    except Image.DecompressionBombError as exc:
        raise ValueError("Image exceeds safe processing limits") from exc
