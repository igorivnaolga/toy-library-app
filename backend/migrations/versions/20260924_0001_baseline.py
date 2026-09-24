"""Baseline: the schema as built by the former supabase/snippets/*.sql files.

Existing databases (already set up from the snippets) must NOT run this; mark
them instead with:

    alembic stamp 0001_baseline

New databases run it via ``alembic upgrade head``. It needs Supabase's ``auth``
and ``storage`` schemas (profiles reference ``auth.users``).

Revision ID: 0001_baseline
Revises:
Create Date: 2026-09-24
"""

from __future__ import annotations

from pathlib import Path

from alembic import op

revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None

_SQL_DIR = Path(__file__).resolve().parent.parent / "sql" / "baseline"


def upgrade() -> None:
    # Files contain multiple statements and $$ function bodies, so run each file
    # through the driver directly (no SQLAlchemy bind-parameter parsing).
    driver_conn = op.get_bind().connection.driver_connection
    for path in sorted(_SQL_DIR.glob("*.sql")):
        driver_conn.execute(path.read_text(encoding="utf-8"))


def downgrade() -> None:
    raise NotImplementedError("The baseline cannot be downgraded; restore from a backup.")
