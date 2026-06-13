"""Supabase Storage helpers for server-side toy photo uploads."""

from __future__ import annotations

import mimetypes
from pathlib import Path

import httpx

from app.core.config import get_settings

_EXT_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


def toy_photos_storage_enabled() -> bool:
    settings = get_settings()
    return bool(settings.supabase_url and settings.supabase_service_role_key)


def toy_photos_public_url(storage_path: str | None) -> str | None:
    """Public CDN URL for a stored object key (e.g. ``J146.jpg``)."""
    if not storage_path or not storage_path.strip():
        return None
    settings = get_settings()
    if not settings.supabase_url:
        return None
    base = settings.supabase_url.rstrip("/")
    bucket = settings.toy_photos_bucket
    key = Path(storage_path.strip()).name
    return f"{base}/storage/v1/object/public/{bucket}/{key}"


def _content_type_for_path(storage_path: str) -> str:
    ext = Path(storage_path).suffix.lower()
    return _EXT_MIME.get(ext) or mimetypes.guess_type(storage_path)[0] or "application/octet-stream"


def upload_toy_photo_bytes(storage_path: str, data: bytes) -> None:
    """Upload or replace a toy photo object in Supabase Storage."""
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise ValueError(
            "Supabase Storage is not configured. Set SUPABASE_URL and "
            "SUPABASE_SERVICE_ROLE_KEY on the server."
        )

    key = Path(storage_path.strip()).name
    if not key or key in (".", ".."):
        raise ValueError("Invalid toy photo storage path.")

    bucket = settings.toy_photos_bucket
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{key}"
    headers = {
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": _content_type_for_path(key),
        "x-upsert": "true",
    }
    with httpx.Client(timeout=60.0) as client:
        response = client.post(url, content=data, headers=headers)
    if response.status_code >= 400:
        raise ValueError(
            f"Supabase upload failed ({response.status_code}): {response.text[:300]}"
        )


def delete_toy_photo(storage_path: str | None) -> None:
    """Best-effort delete of a stored toy photo object."""
    if not storage_path or not storage_path.strip():
        return
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_service_role_key:
        return

    key = Path(storage_path.strip()).name
    if not key or key in (".", ".."):
        return

    bucket = settings.toy_photos_bucket
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{key}"
    headers = {"Authorization": f"Bearer {settings.supabase_service_role_key}"}
    try:
        with httpx.Client(timeout=30.0) as client:
            client.delete(url, headers=headers)
    except httpx.HTTPError:
        return


def download_toy_photo_bytes(storage_path: str) -> bytes | None:
    """Download a toy photo from the public bucket."""
    url = toy_photos_public_url(storage_path)
    if url is None:
        return None
    try:
        with httpx.Client(timeout=30.0, follow_redirects=True) as client:
            response = client.get(url)
        if response.status_code == 404:
            return None
        response.raise_for_status()
        return response.content
    except httpx.HTTPError:
        return None
