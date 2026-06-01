"""
Apply toy_pieces_summary.csv to Postgres toys.total_pieces / missing_pieces.

Run after migration 009_toy_pieces.sql and seed:

  cd backend
  python -m app.scripts.apply_pieces_from_csv
"""

from __future__ import annotations

from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import get_engine, session_scope
from app.models.toy import Toy
from app.services.pieces_from_setls import load_pieces_summary, write_pieces_summary_csv


def main() -> None:
    settings = get_settings()
    if not settings.database_url:
        raise SystemExit(
            "DATABASE_URL is not set. Add it to backend/.env (see backend/.env.example)."
        )

    engine = get_engine()
    if engine is None:
        raise SystemExit("Could not connect to database.")

    summary = load_pieces_summary()
    if not summary:
        try:
            write_pieces_summary_csv()
            load_pieces_summary.cache_clear()
            summary = load_pieces_summary()
        except FileNotFoundError as e:
            raise SystemExit(
                f"{e}\n"
                "Place SETLS export at export_imgs/setls_pieces_export.csv, then run:\n"
                "  python export_imgs/build-toy-pieces-summary.py"
            ) from e

    session = session_scope()
    updated = 0
    skipped = 0
    try:
        toys = session.scalars(
            select(Toy).where(Toy.toy_id.in_(summary.keys()))
        ).all()
        by_id = {t.toy_id: t for t in toys}
        for toy_id, (total, missing) in summary.items():
            toy = by_id.get(toy_id)
            if toy is None:
                skipped += 1
                continue
            toy.total_pieces = total
            toy.missing_pieces = missing if missing > 0 else None
            updated += 1
        session.commit()
    finally:
        session.close()

    print(f"Updated piece counts for {updated} toys.")
    if skipped:
        print(f"Skipped {skipped} toy ids not found in database (re-seed catalog first).")


if __name__ == "__main__":
    main()
