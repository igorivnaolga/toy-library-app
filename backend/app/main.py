"""
FastAPI application entrypoint.

`lifespan` is used for startup/shutdown hooks. We keep DB DDL optional because
production deployments should use migrations instead of `create_all`.
"""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.base import Base
from app.db.session import get_engine

logger = logging.getLogger(__name__)


def _database_startup_hint(exc: OperationalError) -> str | None:
    message = str(exc).lower()
    if "getaddrinfo failed" in message or "network is unreachable" in message:
        return (
            "Cannot reach Supabase Postgres. Direct URLs "
            "(db.<project>.supabase.co) are IPv6-only; many Windows networks "
            "cannot use them. In Supabase → Settings → Database, copy the "
            "**Session pooler** URI (aws-<region>.pooler.supabase.com) into "
            "DATABASE_URL using the postgresql+psycopg:// scheme. "
            "Catalog-only local dev: leave DATABASE_URL empty."
        )
    return None


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
                "ALTER TABLE public.profiles "
                "ADD COLUMN IF NOT EXISTS parent_b_name text, "
                "ADD COLUMN IF NOT EXISTS address_line1 text, "
                "ADD COLUMN IF NOT EXISTS address_line2 text, "
                "ADD COLUMN IF NOT EXISTS suburb text, "
                "ADD COLUMN IF NOT EXISTS mobile_phone text, "
                "ADD COLUMN IF NOT EXISTS alt_contact_name text, "
                "ADD COLUMN IF NOT EXISTS alt_contact_address text, "
                "ADD COLUMN IF NOT EXISTS alt_contact_phone text, "
                "ADD COLUMN IF NOT EXISTS heard_about_us text, "
                "ADD COLUMN IF NOT EXISTS skills text, "
                "ADD COLUMN IF NOT EXISTS text_reminders_consent boolean, "
                "ADD COLUMN IF NOT EXISTS terms_accepted_at timestamptz, "
                "ADD COLUMN IF NOT EXISTS registered_at date"
            )
        )
        conn.execute(
            text(
                """
                DO $$
                BEGIN
                  IF EXISTS (
                    SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = 'profiles'
                      AND column_name = 'home_phone'
                  ) THEN
                    UPDATE public.profiles
                    SET mobile_phone = home_phone
                    WHERE mobile_phone IS NULL AND home_phone IS NOT NULL;
                  END IF;
                END $$;
                """
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
        conn.execute(
            text(
                "ALTER TABLE public.toys "
                "ADD COLUMN IF NOT EXISTS missing_pieces_detail text"
            )
        )
        conn.execute(
            text(
                "ALTER TABLE public.toys "
                "ADD COLUMN IF NOT EXISTS piece_inventory text"
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS public.device_tokens (
                    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                    user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
                    token varchar(512) NOT NULL UNIQUE,
                    platform varchar(16) NOT NULL DEFAULT 'android',
                    updated_at timestamptz NOT NULL DEFAULT now()
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id "
                "ON public.device_tokens (user_id)"
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS public.push_notification_logs (
                    dedupe_key varchar(256) PRIMARY KEY,
                    user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
                    sent_at timestamptz NOT NULL DEFAULT now()
                )
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_push_notification_logs_user_id "
                "ON public.push_notification_logs (user_id)"
            )
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    engine = get_engine()
    if settings.database_url and engine is not None:
        try:
            _apply_schema_patches(engine)
            if settings.create_tables_on_startup:
                # Dev-only convenience: create ORM tables if they don't exist yet.
                Base.metadata.create_all(bind=engine)
        except OperationalError as exc:
            hint = _database_startup_hint(exc)
            if hint:
                logger.error(hint)
                raise RuntimeError(hint) from exc
            raise
    yield


app = FastAPI(title="Toy Library API", version="0.1.0", lifespan=lifespan)
app.include_router(api_router, prefix="/api/v1")
