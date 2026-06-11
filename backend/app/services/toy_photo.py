"""Resolve on-disk paths for toy photos served by `GET /api/v1/toys/{toy_id}/photo`."""

from __future__ import annotations

import mimetypes
from pathlib import Path

from app.core.config import get_settings
from app.services.toy_service import get_toy_service


def resolve_toy_images_root() -> Path | None:
    """Directory containing image files (basename must match `photo_file` from the API)."""
    settings = get_settings()
    if settings.toy_images_dir:
        p = Path(settings.toy_images_dir).expanduser().resolve()
        return p if p.is_dir() else None
    # If unset, use `<repo>/toy_library_photos` when that folder exists (local dev; often gitignored).
    here = Path(__file__).resolve()
    fallback = here.parents[3] / "toy_library_photos"
    if fallback.is_dir():
        return fallback.resolve()
    return None


def resolve_toy_photo_path(toy_id: str) -> Path | None:
    """Return absolute path to the image file for this toy, or None if missing/not configured."""
    root = resolve_toy_images_root()
    if root is None:
        return None

    toy = get_toy_service(toy_id)
    if toy is None or not toy.photo_file:
        return None

    # Only the basename is allowed inside `root` (prevents path traversal).
    safe_name = Path(toy.photo_file).name
    if not safe_name or safe_name in (".", ".."):
        return None

    candidate = (root / safe_name).resolve()
    root_r = root.resolve()
    if not str(candidate).startswith(str(root_r)):
        return None
    return candidate if candidate.is_file() else None


def guess_media_type(path: Path) -> str:
    mime, _ = mimetypes.guess_type(str(path))
    return mime or "application/octet-stream"


def safe_delete_photo_file(root: Path, filename: str | None) -> None:
    if not filename:
        return
    safe_name = Path(filename).name
    if not safe_name or safe_name in (".", ".."):
        return
    candidate = (root / safe_name).resolve()
    root_r = root.resolve()
    if not str(candidate).startswith(str(root_r)):
        return
    if candidate.is_file():
        candidate.unlink(missing_ok=True)
