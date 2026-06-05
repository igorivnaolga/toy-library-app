"""
Apply setls_rental_prices.csv to Postgres toys.rental_price_cents.

Run after migration 011_rental_price.sql:

  cd backend
  python -m app.scripts.apply_rental_prices_from_csv
"""

from __future__ import annotations

from sqlalchemy import select

from app.core.config import get_settings
from app.db.session import get_engine, session_scope
from app.models.toy import Toy
from app.services.rental_price_from_setls import load_rental_prices


def main() -> None:
    settings = get_settings()
    if not settings.database_url:
        raise SystemExit(
            "DATABASE_URL is not set. Add it to backend/.env (see backend/.env.example)."
        )

    engine = get_engine()
    if engine is None:
        raise SystemExit("Could not connect to database.")

    prices = load_rental_prices()
    if not prices:
        raise SystemExit(
            "No rental prices found. Run:\n"
            "  python export_imgs/build-setls-rental-prices.py"
        )

    session = session_scope()
    updated = 0
    skipped = 0
    try:
        toys = session.scalars(
            select(Toy).where(Toy.toy_id.in_(prices.keys()))
        ).all()
        by_id = {t.toy_id: t for t in toys}
        for toy_id, cents in prices.items():
            toy = by_id.get(toy_id)
            if toy is None:
                skipped += 1
                continue
            toy.rental_price_cents = cents
            updated += 1
        session.commit()
    finally:
        session.close()

    print(f"Updated rental prices for {updated} toys.")
    if skipped:
        print(f"Skipped {skipped} toy ids not found in database (re-seed catalog first).")


if __name__ == "__main__":
    main()
