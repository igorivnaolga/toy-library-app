"""
CLI entrypoint: import seed CSVs into Postgres.

This is intentionally separate from FastAPI request handling:
- it can be run in CI / locally without starting a web server
- it performs DDL (`create_all`) for early development convenience
"""

from app.core.config import get_settings
from app.db.base import Base
from app.db.session import get_engine, session_scope
from app.services.seed_from_csv import seed_catalog


def main() -> None:
    settings = get_settings()
    if not settings.database_url:
        raise SystemExit("DATABASE_URL is not set. Copy backend/.env.example to backend/.env.")

    engine = get_engine()
    assert engine is not None
    # Dev convenience: create tables if missing. For production, prefer Alembic migrations.
    Base.metadata.create_all(bind=engine)

    session = session_scope()
    try:
        cats, toys = seed_catalog(session)
        print(f"Seed complete. New categories: {cats}, new toys: {toys}.")
    finally:
        session.close()


if __name__ == "__main__":
    main()
