"""
FastAPI application entrypoint.

`lifespan` is used for startup/shutdown hooks. We keep DB DDL optional because
production deployments should use migrations instead of `create_all`.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.base import Base
from app.db.session import get_engine


def _apply_schema_patches(engine) -> None:
    """Idempotent DDL for columns added after initial deploy."""
    with engine.begin() as conn:
        conn.execute(
            text(
                "ALTER TABLE public.profiles "
                "ADD COLUMN IF NOT EXISTS admin_notes text"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE public.toys "
                "ADD COLUMN IF NOT EXISTS rental_price_cents integer"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE public.toys "
                "ADD COLUMN IF NOT EXISTS cv_learn_piece_count integer, "
                "ADD COLUMN IF NOT EXISTS cv_learn_fg_pixels integer, "
                "ADD COLUMN IF NOT EXISTS cv_learn_peak_count integer, "
                "ADD COLUMN IF NOT EXISTS cv_learn_samples integer NOT NULL DEFAULT 0"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE public.duty_sessions "
                "ADD COLUMN IF NOT EXISTS admin_confirmed_at timestamptz, "
                "ADD COLUMN IF NOT EXISTS admin_confirmed_by uuid "
                "REFERENCES public.profiles (id) ON DELETE SET NULL"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE public.toys "
                "ADD COLUMN IF NOT EXISTS cv_ref_piece_count integer, "
                "ADD COLUMN IF NOT EXISTS cv_ref_fg_pixels integer, "
                "ADD COLUMN IF NOT EXISTS cv_ref_peak_count integer, "
                "ADD COLUMN IF NOT EXISTS cv_ref_blob_count integer, "
                "ADD COLUMN IF NOT EXISTS cv_ref_image_area integer, "
                "ADD COLUMN IF NOT EXISTS cv_ref_layout text, "
                "ADD COLUMN IF NOT EXISTS cv_ref_source varchar(16)"
            )
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    engine = get_engine()
    if settings.database_url and engine is not None:
        _apply_schema_patches(engine)
        if settings.create_tables_on_startup:
            # Dev-only convenience: create ORM tables if they don't exist yet.
            Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Toy Library API", version="0.1.0", lifespan=lifespan)
app.include_router(api_router, prefix="/api/v1")
