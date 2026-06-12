"""CLI: import SETLS catalog CSVs into snapshot tables for admin statistics."""

from __future__ import annotations

import sys

from app.db.session import session_scope
from app.services.setls_import_service import import_setls_catalog_snapshot


def main() -> int:
    session = session_scope()
    try:
        run = import_setls_catalog_snapshot(session)
        session.commit()
    except Exception as exc:
        session.rollback()
        print(f"Import failed: {exc}", file=sys.stderr)
        return 1
    finally:
        session.close()

    print(
        f"Imported SETLS snapshot {run.id}: "
        f"{run.toy_count} toys, {run.category_count} categories."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
