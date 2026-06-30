"""
FastAPI application entrypoint.

`lifespan` is used for startup/shutdown hooks. We keep DB DDL optional because
production deployments should use migrations instead of `create_all`.
"""

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text
from sqlalchemy.engine import Engine
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


def _execute_schema_statement(engine: Engine, sql: str, *, label: str) -> None:
    """Run one DDL/DML patch in its own transaction with a longer timeout."""
    last_error: OperationalError | None = None
    for attempt in range(3):
        try:
            with engine.connect() as conn:
                # Supabase pooler defaults can cancel long ALTER TABLE statements.
                conn.execute(text("SET statement_timeout = 0"))
                conn.execute(text("SET lock_timeout = '30s'"))
                conn.execute(text(sql))
                conn.commit()
            return
        except OperationalError as exc:
            last_error = exc
            message = str(exc).lower()
            retryable = (
                "lock timeout" in message
                or "deadlock" in message
                or "statement timeout" in message
                or "query canceled" in message
            )
            if not retryable or attempt == 2:
                logger.error("Schema patch failed (%s): %s", label, exc)
                raise
            delay = 2**attempt
            logger.warning(
                "Schema patch retry %s/%s for %s in %ss (%s)",
                attempt + 2,
                3,
                label,
                delay,
                exc,
            )
            time.sleep(delay)
    if last_error is not None:
        raise last_error


def _apply_schema_patches(engine: Engine) -> None:
    """Idempotent DDL for columns added after initial deploy."""
    patches: list[tuple[str, str]] = [
        (
            "profiles.admin_notes",
            "ALTER TABLE public.profiles "
            "ADD COLUMN IF NOT EXISTS admin_notes text",
        ),
        (
            "toys.rental_price_cents",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS rental_price_cents integer",
        ),
        (
            "toys.cv_learn_columns",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS cv_learn_piece_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_fg_pixels integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_peak_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_samples integer NOT NULL DEFAULT 0",
        ),
        (
            "duty_sessions.admin_confirmed",
            "ALTER TABLE public.duty_sessions "
            "ADD COLUMN IF NOT EXISTS admin_confirmed_at timestamptz, "
            "ADD COLUMN IF NOT EXISTS admin_confirmed_by uuid "
            "REFERENCES public.profiles (id) ON DELETE SET NULL",
        ),
        (
            "profiles.registration_fields",
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
            "ADD COLUMN IF NOT EXISTS registered_at date",
        ),
        (
            "profiles.home_phone_backfill",
            """
            DO $$
            BEGIN
              IF EXISTS (
                SELECT 1 FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'profiles'
                  AND column_name = 'home_phone'
              ) AND EXISTS (
                SELECT 1 FROM public.profiles
                WHERE mobile_phone IS NULL AND home_phone IS NOT NULL
                LIMIT 1
              ) THEN
                UPDATE public.profiles
                SET mobile_phone = home_phone
                WHERE mobile_phone IS NULL AND home_phone IS NOT NULL;
              END IF;
            END $$;
            """,
        ),
        (
            "toys.cv_ref_columns",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS cv_ref_piece_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_ref_fg_pixels integer, "
            "ADD COLUMN IF NOT EXISTS cv_ref_peak_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_ref_blob_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_ref_image_area integer, "
            "ADD COLUMN IF NOT EXISTS cv_ref_layout text, "
            "ADD COLUMN IF NOT EXISTS cv_ref_source varchar(16)",
        ),
        (
            "toys.missing_pieces_detail",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS missing_pieces_detail text",
        ),
        (
            "toys.piece_inventory",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS piece_inventory text",
        ),
        (
            "device_tokens.table",
            """
            CREATE TABLE IF NOT EXISTS public.device_tokens (
                id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
                token varchar(512) NOT NULL UNIQUE,
                platform varchar(16) NOT NULL DEFAULT 'android',
                updated_at timestamptz NOT NULL DEFAULT now()
            )
            """,
        ),
        (
            "device_tokens.user_id_index",
            "CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id "
            "ON public.device_tokens (user_id)",
        ),
        (
            "push_notification_logs.table",
            """
            CREATE TABLE IF NOT EXISTS public.push_notification_logs (
                dedupe_key varchar(256) PRIMARY KEY,
                user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
                sent_at timestamptz NOT NULL DEFAULT now()
            )
            """,
        ),
        (
            "push_notification_logs.user_id_index",
            "CREATE INDEX IF NOT EXISTS ix_push_notification_logs_user_id "
            "ON public.push_notification_logs (user_id)",
        ),
        (
            "library_events.table",
            """
            CREATE TABLE IF NOT EXISTS public.library_events (
              id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
              name text NOT NULL,
              description text,
              event_date date NOT NULL,
              is_published boolean NOT NULL DEFAULT true,
              created_by uuid REFERENCES public.profiles (id) ON DELETE SET NULL,
              created_at timestamptz NOT NULL DEFAULT now(),
              updated_at timestamptz DEFAULT now()
            )
            """,
        ),
        (
            "library_events.end_date",
            "ALTER TABLE public.library_events "
            "ADD COLUMN IF NOT EXISTS end_date date",
        ),
        (
            "library_events.end_date_backfill",
            """
            UPDATE public.library_events
            SET end_date = event_date
            WHERE end_date IS NULL
            """,
        ),
        (
            "event_time_slots.table",
            """
            CREATE TABLE IF NOT EXISTS public.event_time_slots (
              id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
              event_id uuid NOT NULL REFERENCES public.library_events (id) ON DELETE CASCADE,
              start_time time NOT NULL,
              end_time time NOT NULL,
              capacity integer NOT NULL CHECK (capacity >= 1),
              audience text NOT NULL CHECK (audience IN ('volunteer', 'member')),
              created_at timestamptz NOT NULL DEFAULT now(),
              CHECK (end_time > start_time)
            )
            """,
        ),
        (
            "event_bookings.table",
            """
            CREATE TABLE IF NOT EXISTS public.event_bookings (
              id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
              slot_id uuid NOT NULL REFERENCES public.event_time_slots (id) ON DELETE CASCADE,
              user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
              booked_at timestamptz NOT NULL DEFAULT now(),
              UNIQUE (slot_id, user_id)
            )
            """,
        ),
    ]

    for label, sql in patches:
        logger.info("Applying schema patch: %s", label)
        _execute_schema_statement(engine, sql, label=label)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    engine = get_engine()
    if settings.database_url and engine is not None:
        try:
            if settings.apply_schema_patches_on_startup:
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
