"""Security and integrity hardening from the 2026-09 review.

- Row-level security on every app table (tables created by the old startup
  DDL or ``create_all`` never had it, leaving them open to PostgREST).
- Revoke direct table access from Supabase ``anon``/``authenticated`` roles:
  clients go through the FastAPI backend only.
- Payment/loan/booking history: ``ON DELETE RESTRICT`` instead of CASCADE.
- ``payments.idempotency_key`` for retry-safe top-ups.
- Columns and indexes that previously only existed in startup patches.

Every statement is idempotent so it is safe on databases built either from the
SQL snippets or from the old startup DDL.

Revision ID: 0002_security_integrity
Revises: 0001_baseline
Create Date: 2026-09-24
"""

from __future__ import annotations

from alembic import op

revision = "0002_security_integrity"
down_revision = "0001_baseline"
branch_labels = None
depends_on = None

APP_TABLES = (
    "profiles",
    "categories",
    "toys",
    "toy_images",
    "bookings",
    "loans",
    "duty_sessions",
    "payments",
    "device_tokens",
    "push_notification_logs",
    "library_events",
    "event_time_slots",
    "event_bookings",
    "setls_import_runs",
    "setls_category_stats",
    "setls_toy_status_counts",
)

# (table, constraint) whose user_id FK becomes ON DELETE RESTRICT.
HISTORY_FKS = (
    ("payments", "payments_user_id_fkey"),
    ("loans", "loans_user_id_fkey"),
    ("bookings", "bookings_user_id_fkey"),
)


def _table_array() -> str:
    return "array[" + ", ".join(f"'{name}'" for name in APP_TABLES) + "]"


def upgrade() -> None:
    op.execute(
        f"""
        DO $$
        DECLARE t text;
        BEGIN
          FOREACH t IN ARRAY {_table_array()} LOOP
            IF to_regclass('public.' || t) IS NOT NULL THEN
              EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
              IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
                EXECUTE format('REVOKE ALL ON public.%I FROM anon', t);
              END IF;
              IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
                EXECUTE format('REVOKE ALL ON public.%I FROM authenticated', t);
              END IF;
            END IF;
          END LOOP;
        END $$;
        """
    )

    for table, constraint in HISTORY_FKS:
        op.execute(
            f"""
            ALTER TABLE public.{table}
              DROP CONSTRAINT IF EXISTS {constraint},
              ADD CONSTRAINT {constraint}
                FOREIGN KEY (user_id) REFERENCES public.profiles (id) ON DELETE RESTRICT
            """
        )

    op.execute("ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS idempotency_key varchar(64)")
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_user_idempotency_key
          ON public.payments (user_id, idempotency_key)
          WHERE idempotency_key IS NOT NULL
        """
    )

    # Previously only created by startup patches (never in the snippets).
    op.execute(
        "ALTER TABLE public.toys "
        "ADD COLUMN IF NOT EXISTS missing_pieces_detail text, "
        "ADD COLUMN IF NOT EXISTS piece_inventory text"
    )
    op.execute(
        """
        DO $$
        BEGIN
          IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles'
              AND column_name = 'home_phone'
          ) THEN
            UPDATE public.profiles
            SET mobile_phone = home_phone
            WHERE mobile_phone IS NULL AND home_phone IS NOT NULL;
          END IF;
        END $$;
        """
    )

    # Integrity indexes the API relies on (missing on create_all-built databases).
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_one_pending_per_toy
          ON public.bookings (toy_id) WHERE status = 'pending'
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_one_pending_per_user_toy
          ON public.bookings (user_id, toy_id) WHERE status = 'pending'
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_loans_one_active_per_toy
          ON public.loans (toy_id) WHERE status = 'active'
        """
    )
    op.execute(
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_duty_sessions_slot
          ON public.duty_sessions (session_date, start_time, end_time)
        """
    )


def downgrade() -> None:
    for table, constraint in HISTORY_FKS:
        op.execute(
            f"""
            ALTER TABLE public.{table}
              DROP CONSTRAINT IF EXISTS {constraint},
              ADD CONSTRAINT {constraint}
                FOREIGN KEY (user_id) REFERENCES public.profiles (id) ON DELETE CASCADE
            """
        )
    op.execute("DROP INDEX IF EXISTS public.idx_payments_user_idempotency_key")
    op.execute("ALTER TABLE public.payments DROP COLUMN IF EXISTS idempotency_key")
    # RLS, revoked grants and integrity indexes are intentionally left in place.
