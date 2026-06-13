"""
Upload existing on-disk toy photos to Supabase Storage.

Requires DATABASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and a local photo folder
(TOY_IMAGES_DIR or <repo>/toy_library_photos).

Run from backend/:

    python -m app.scripts.migrate_toy_photos_to_supabase
"""

from __future__ import annotations

from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.core.config import get_settings
from app.db.session import get_engine, session_scope
from app.models.toy import Toy
from app.services.supabase_storage import (
    toy_photos_storage_enabled,
    upload_toy_photo_bytes,
)
from app.services.toy_photo import resolve_toy_images_root


def main() -> None:
    settings = get_settings()
    if not settings.database_url:
        raise SystemExit("DATABASE_URL is not set.")
    if not toy_photos_storage_enabled():
        raise SystemExit(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before migrating photos."
        )

    root = resolve_toy_images_root()
    if root is None:
        raise SystemExit(
            "Local toy photos folder not found. Set TOY_IMAGES_DIR or create "
            "<repo>/toy_library_photos."
        )

    if get_engine() is None:
        raise SystemExit("Could not connect to the database.")

    session = session_scope()
    uploaded = 0
    skipped = 0
    missing = 0
    try:
        toys = session.scalars(
            select(Toy).options(joinedload(Toy.image)).order_by(Toy.toy_id)
        ).all()
        for toy in toys:
            filename = toy.image.filename if toy.image else None
            if not filename:
                skipped += 1
                continue

            safe_name = Path(filename).name
            local_path = root / safe_name
            if not local_path.is_file():
                missing += 1
                print(f"  missing local file: {toy.toy_id} -> {safe_name}")
                continue

            upload_toy_photo_bytes(safe_name, local_path.read_bytes())
            uploaded += 1
            if uploaded % 50 == 0:
                print(f"  uploaded {uploaded}...")
    finally:
        session.close()

    print(
        f"Migration complete. Uploaded: {uploaded}, "
        f"skipped (no filename): {skipped}, missing on disk: {missing}."
    )


if __name__ == "__main__":
    main()
