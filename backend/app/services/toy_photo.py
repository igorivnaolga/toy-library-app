"""Resolve toy photo paths/URLs for serving and CV reference loading."""

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
    """Return absolute path to the on-disk image file, or None if missing/not configured."""
    from app.services.supabase_storage import toy_photos_storage_enabled

    if toy_photos_storage_enabled():
        return None

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


def resolve_toy_photo_public_url(toy_id: str) -> str | None:
    """Public Supabase URL when storage is configured; otherwise None."""
    from app.services.supabase_storage import toy_photos_public_url, toy_photos_storage_enabled

    if not toy_photos_storage_enabled():
        return None

    toy = get_toy_service(toy_id)
    if toy is None or not toy.photo_file:
        return None
    return toy_photos_public_url(toy.photo_file)


def read_toy_photo_bytes(toy_id: str) -> bytes | None:
    """Load toy photo bytes from Supabase or local disk."""
    from app.services.supabase_storage import (
        download_toy_photo_bytes,
        toy_photos_storage_enabled,
    )

    toy = get_toy_service(toy_id)
    if toy is None or not toy.photo_file:
        return None

    if toy_photos_storage_enabled():
        return download_toy_photo_bytes(toy.photo_file)

    path = resolve_toy_photo_path(toy_id)
    if path is None:
        return None
    return path.read_bytes()


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
