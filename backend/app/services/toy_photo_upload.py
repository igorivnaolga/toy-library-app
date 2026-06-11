"""Save admin-uploaded toy photos to disk and ``toy_images``."""

from __future__ import annotations

from pathlib import Path

from app.schemas.toy import ToyOut
from app.services.toy_photo import resolve_toy_images_root

_MAX_BYTES = 8 * 1024 * 1024

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


def upload_toy_photo_service(
    toy_id: str,
    data: bytes,
    *,
    content_type: str | None = None,
) -> ToyOut | None:
    if not data:
        raise ValueError("Empty image upload.")
    if len(data) > _MAX_BYTES:
        raise ValueError("Image is too large.")

    root = resolve_toy_images_root()
    if root is None:
        raise ValueError(
            "Toy photo storage is not configured. Set TOY_IMAGES_DIR on the server."
        )

    ext = _extension_for_upload(content_type, data)
    from app.repositories.toy_repo import upload_toy_photo_in_db

    return upload_toy_photo_in_db(
        toy_id,
        image_bytes=data,
        filename_suffix=ext,
        storage_root=root,
    )
