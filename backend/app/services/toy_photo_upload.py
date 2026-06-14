"""Save admin-uploaded toy photos to Supabase Storage or disk and ``toy_images``."""

from __future__ import annotations

from pathlib import Path

from app.schemas.toy import ToyOut
from app.services.supabase_storage import (
    delete_toy_photo,
    toy_photos_storage_enabled,
    upload_toy_photo_bytes,
)
from app.services.toy_photo import resolve_toy_images_root
from app.services.toy_photo_normalize import normalize_toy_photo_bytes

_MAX_BYTES = 8 * 1024 * 1024
_CATALOG_EXT = ".jpg"

_CONTENT_TYPE_EXT = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


def _extension_for_upload(content_type: str | None, data: bytes) -> str:
    ct = (content_type or "").split(";")[0].strip().lower()
    if ct in _CONTENT_TYPE_EXT:
        return _CONTENT_TYPE_EXT[ct]
    if len(data) >= 3 and data[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    raise ValueError("Unsupported image format. Use JPEG, PNG, or WebP.")


def _prepare_toy_photo_bytes(data: bytes, *, content_type: str | None) -> bytes:
    if not data:
        raise ValueError("Empty image upload.")
    if len(data) > _MAX_BYTES:
        raise ValueError("Image is too large.")
    _extension_for_upload(content_type, data)
    normalized = normalize_toy_photo_bytes(data)
    if len(normalized) > _MAX_BYTES:
        raise ValueError("Image is too large after processing.")
    return normalized


def upload_toy_photo_service(
    toy_id: str,
    data: bytes,
    *,
    content_type: str | None = None,
) -> ToyOut | None:
    data = _prepare_toy_photo_bytes(data, content_type=content_type)
    from app.repositories.toy_repo import update_toy_photo_filename_in_db

    if toy_photos_storage_enabled():
        toy_id_norm = toy_id.strip()
        new_filename = f"{toy_id_norm}{_CATALOG_EXT}"
        upload_toy_photo_bytes(new_filename, data)
        updated, old_filename = update_toy_photo_filename_in_db(toy_id_norm, new_filename)
        if old_filename and old_filename != new_filename:
            delete_toy_photo(old_filename)
        return updated

    root = resolve_toy_images_root()
    if root is None:
        raise ValueError(
            "Toy photo storage is not configured. Set SUPABASE_SERVICE_ROLE_KEY "
            "for Supabase Storage, or TOY_IMAGES_DIR for local files."
        )

    from app.repositories.toy_repo import upload_toy_photo_in_db

    return upload_toy_photo_in_db(
        toy_id,
        image_bytes=data,
        filename_suffix=_CATALOG_EXT,
        storage_root=root,
    )
