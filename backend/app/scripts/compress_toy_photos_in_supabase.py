"""
Re-compress toy photos already stored in Supabase Storage.

Requires DATABASE_URL, SUPABASE_URL, and SUPABASE_SERVICE_ROLE_KEY.

Run from backend/:

    python -m app.scripts.compress_toy_photos_in_supabase
    python -m app.scripts.compress_toy_photos_in_supabase --dry-run
"""

from __future__ import annotations

import argparse
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from app.core.config import get_settings
from app.db.session import get_engine, session_scope
from app.models.toy import Toy
from app.services.supabase_storage import (
    delete_toy_photo,
    download_toy_photo_bytes,
    toy_photos_storage_enabled,
    upload_toy_photo_bytes,
)
from app.services.toy_photo_normalize import normalize_toy_photo_bytes

_CATALOG_EXT = ".jpg"
_MIN_SAVINGS_RATIO = 0.95


def _target_filename(toy_id: str) -> str:
    return f"{toy_id.strip()}{_CATALOG_EXT}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compress existing toy photos in Supabase Storage."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report changes without uploading or updating the database.",
    )
    args = parser.parse_args()

    settings = get_settings()
    if not settings.database_url:
        raise SystemExit("DATABASE_URL is not set.")
    if not toy_photos_storage_enabled():
        raise SystemExit(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before compressing photos."
        )
    if get_engine() is None:
        raise SystemExit("Could not connect to the database.")

    session = session_scope()
    uploaded = 0
    skipped = 0
    missing = 0
    failed = 0
    saved_bytes = 0
    try:
        toys = session.scalars(
            select(Toy).options(joinedload(Toy.image)).order_by(Toy.toy_id)
        ).all()
        for toy in toys:
            filename = toy.image.filename if toy.image else None
            if not filename:
                skipped += 1
                continue

            raw = download_toy_photo_bytes(filename)
            if raw is None:
                missing += 1
                print(f"  missing in storage: {toy.toy_id} -> {filename}")
                continue

            try:
                normalized = normalize_toy_photo_bytes(raw)
            except ValueError as exc:
                failed += 1
                print(f"  failed {toy.toy_id}: {exc}")
                continue

            new_filename = _target_filename(toy.toy_id)
            same_name = Path(filename).name == new_filename
            worth_upload = (
                not same_name
                or len(normalized) < len(raw) * _MIN_SAVINGS_RATIO
            )
            if not worth_upload:
                skipped += 1
                continue

            delta = len(raw) - len(normalized)
            if args.dry_run:
                print(
                    f"  would compress {toy.toy_id}: "
                    f"{len(raw)} -> {len(normalized)} bytes "
                    f"({filename} -> {new_filename})"
                )
                uploaded += 1
                saved_bytes += max(0, delta)
                continue

            upload_toy_photo_bytes(new_filename, normalized)
            if new_filename != Path(filename).name:
                from app.repositories.toy_repo import update_toy_photo_filename_in_db

                update_toy_photo_filename_in_db(toy.toy_id, new_filename)
                delete_toy_photo(filename)

            uploaded += 1
            saved_bytes += max(0, delta)
            if uploaded % 50 == 0:
                print(f"  compressed {uploaded}...")
    finally:
        session.close()

    mode = "Dry run" if args.dry_run else "Compression"
    print(
        f"{mode} complete. Processed: {uploaded}, skipped: {skipped}, "
        f"missing: {missing}, failed: {failed}, "
        f"bytes saved: {saved_bytes:,}."
    )


if __name__ == "__main__":
    main()
