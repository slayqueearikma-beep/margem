import re
from pathlib import PurePosixPath

_ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/gif",
}
_MAX_FILENAME_LENGTH = 120


def sanitize_upload_filename(filename: str) -> str:
    name = PurePosixPath(filename).name
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name).strip("._")
    if not name:
        raise ValueError("Invalid filename")
    return name[:_MAX_FILENAME_LENGTH]


def validate_upload_content_type(content_type: str) -> None:
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise ValueError(f"Unsupported content type: {content_type}")
