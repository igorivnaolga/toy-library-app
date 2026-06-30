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


def _all_columns_exist(
    engine: Engine,
    table: str,
    columns: tuple[str, ...],
) -> bool:
    if not columns:
        return True
    placeholders = ", ".join(f":c{i}" for i in range(len(columns)))
    params = {f"c{i}": name for i, name in enumerate(columns)}
    params["table"] = table
    with engine.connect() as conn:
        count = conn.execute(
            text(
                f"""
                select count(distinct column_name)
                from information_schema.columns
                where table_schema = 'public'
                  and table_name = :table
                  and column_name in ({placeholders})
                """
            ),
            params,
        ).scalar_one()
    return int(count or 0) == len(columns)


def _table_exists(engine: Engine, table: str) -> bool:
    with engine.connect() as conn:
        exists = conn.execute(
            text(
                """
                select exists (
                  select 1 from information_schema.tables
                  where table_schema = 'public' and table_name = :table
                )
                """
            ),
            {"table": table},
        ).scalar_one()
    return bool(exists)


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


def _apply_schema_patches(engine: Engine, *, strict: bool = False) -> None:
    """Idempotent DDL for columns added after initial deploy."""
    # (label, sql, optional skip-if-already-applied check)
    Patch = tuple[str, str, tuple[str, tuple[str, ...] | None] | None]
    patches: list[Patch] = [
        (
            "profiles.admin_notes",
            "ALTER TABLE public.profiles "
            "ADD COLUMN IF NOT EXISTS admin_notes text",
            ("profiles", ("admin_notes",)),
        ),
        (
            "toys.rental_price_cents",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS rental_price_cents integer",
            ("toys", ("rental_price_cents",)),
        ),
        (
            "toys.cv_learn_columns",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS cv_learn_piece_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_fg_pixels integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_peak_count integer, "
            "ADD COLUMN IF NOT EXISTS cv_learn_samples integer NOT NULL DEFAULT 0",
            (
                "toys",
                (
                    "cv_learn_piece_count",
                    "cv_learn_fg_pixels",
                    "cv_learn_peak_count",
                    "cv_learn_samples",
                ),
            ),
        ),
        (
            "duty_sessions.admin_confirmed",
            "ALTER TABLE public.duty_sessions "
            "ADD COLUMN IF NOT EXISTS admin_confirmed_at timestamptz, "
            "ADD COLUMN IF NOT EXISTS admin_confirmed_by uuid "
            "REFERENCES public.profiles (id) ON DELETE SET NULL",
            ("duty_sessions", ("admin_confirmed_at", "admin_confirmed_by")),
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
            (
                "profiles",
                (
                    "parent_b_name",
                    "address_line1",
                    "address_line2",
                    "suburb",
                    "mobile_phone",
                    "alt_contact_name",
                    "alt_contact_address",
                    "alt_contact_phone",
                    "heard_about_us",
                    "skills",
                    "text_reminders_consent",
                    "terms_accepted_at",
                    "registered_at",
                ),
            ),
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
            None,
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
            (
                "toys",
                (
                    "cv_ref_piece_count",
                    "cv_ref_fg_pixels",
                    "cv_ref_peak_count",
                    "cv_ref_blob_count",
                    "cv_ref_image_area",
                    "cv_ref_layout",
                    "cv_ref_source",
                ),
            ),
        ),
        (
            "toys.missing_pieces_detail",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS missing_pieces_detail text",
            ("toys", ("missing_pieces_detail",)),
        ),
        (
            "toys.piece_inventory",
            "ALTER TABLE public.toys "
            "ADD COLUMN IF NOT EXISTS piece_inventory text",
            ("toys", ("piece_inventory",)),
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
            ("device_tokens", None),
        ),
        (
            "device_tokens.user_id_index",
            "CREATE INDEX IF NOT EXISTS ix_device_tokens_user_id "
            "ON public.device_tokens (user_id)",
            None,
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
            ("push_notification_logs", None),
        ),
        (
            "push_notification_logs.user_id_index",
            "CREATE INDEX IF NOT EXISTS ix_push_notification_logs_user_id "
            "ON public.push_notification_logs (user_id)",
            None,
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
            ("library_events", None),
        ),
        (
            "library_events.end_date",
            "ALTER TABLE public.library_events "
            "ADD COLUMN IF NOT EXISTS end_date date",
            ("library_events", ("end_date",)),
        ),
        (
            "library_events.end_date_backfill",
            """
            UPDATE public.library_events
            SET end_date = event_date
            WHERE end_date IS NULL
            """,
            None,
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
            ("event_time_slots", None),
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
            ("event_bookings", None),
        ),
    ]

    failed: list[str] = []
    for label, sql, skip_check in patches:
        if skip_check is not None:
            table, columns = skip_check
            if columns is None:
                if _table_exists(engine, table):
                    logger.info("Schema patch already applied: %s", label)
                    continue
            elif _all_columns_exist(engine, table, columns):
                logger.info("Schema patch already applied: %s", label)
                continue
        logger.info("Applying schema patch: %s", label)
        try:
            _execute_schema_statement(engine, sql, label=label)
        except OperationalError as exc:
            if strict:
                raise
            logger.warning(
                "Schema patch skipped (%s): %s — apply SQL in Supabase if needed.",
                label,
                exc,
            )
            failed.append(label)
    if failed:
        logger.warning(
            "Some schema patches did not run: %s",
            ", ".join(failed),
        )


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    engine = get_engine()
    if settings.database_url and engine is not None:
        try:
            if settings.apply_schema_patches_on_startup:
                _apply_schema_patches(
                    engine,
                    strict=settings.schema_patches_strict,
                )
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
