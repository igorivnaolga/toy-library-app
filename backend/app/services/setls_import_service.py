"""Import SETLS catalog exports into snapshot tables for admin statistics."""

from __future__ import annotations

import csv
from collections import Counter
from decimal import Decimal
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.models.setls_stats import SetlsCategoryStat, SetlsImportRun, SetlsToyStatusCount
from app.utils.csv_text import (
    clean_cell,
    get_norm,
    row_normalized,
    to_optional_bool,
    to_optional_int,
)

EXPORT_ROOT = Path(__file__).resolve().parents[3] / "export_imgs"
CATEGORIES_CSV = EXPORT_ROOT / "Toys-categories.csv"
TOYS_LIST_CSV = EXPORT_ROOT / "Toys-list.csv"


def _parse_pct(value: str | None) -> Decimal | None:
    raw = clean_cell(value)
    if raw is None:
        return None
    raw = raw.replace("%", "").strip()
    if not raw:
        return None
    try:
        return Decimal(raw)
    except Exception:
        return None


def read_setls_category_rows(
    categories_path: Path = CATEGORIES_CSV,
) -> list[dict[str, object]]:
    if not categories_path.is_file():
        raise FileNotFoundError(f"SETLS categories CSV not found: {categories_path}")
    rows: list[dict[str, object]] = []
    with categories_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        for raw in reader:
            norm = row_normalized(raw)
            code = get_norm(norm, "code")
            if not code:
                continue
            rows.append(
                {
                    "code": code,
                    "description": get_norm(norm, "description"),
                    "current_toys": to_optional_int(
                        get_norm(norm, "ofcurrenttoys")
                    ),
                    "total_toys": to_optional_int(get_norm(norm, "oftotaltoys")),
                    "pct_share": _parse_pct(get_norm(norm, "pct")),
                    "reservable": to_optional_bool(get_norm(norm, "reservable")),
                    "max_renewals": to_optional_int(
                        get_norm(norm, "maxrenewals")
                    ),
                }
            )
    return rows


def read_setls_toy_status_counts(
    toys_path: Path = TOYS_LIST_CSV,
) -> dict[str, int]:
    if not toys_path.is_file():
        raise FileNotFoundError(f"SETLS toys list CSV not found: {toys_path}")
    counts: Counter[str] = Counter()
    with toys_path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        for raw in reader:
            norm = row_normalized(raw)
            toy_id = get_norm(norm, "id")
            if not toy_id:
                continue
            status = get_norm(norm, "status") or "Unknown"
            counts[status] += 1
    return dict(counts)


def import_setls_catalog_snapshot(
    session: Session,
    *,
    categories_path: Path = CATEGORIES_CSV,
    toys_path: Path = TOYS_LIST_CSV,
    source_label: str = "export_imgs",
) -> SetlsImportRun:
    """Load latest SETLS CSV exports into snapshot tables (replaces prior rows)."""
    category_rows = read_setls_category_rows(categories_path)
    status_counts = read_setls_toy_status_counts(toys_path)
    toy_total = sum(status_counts.values())

    session.execute(delete(SetlsToyStatusCount))
    session.execute(delete(SetlsCategoryStat))
    session.execute(delete(SetlsImportRun))
    session.flush()

    run = SetlsImportRun(
        source_label=source_label,
        toy_count=toy_total,
        category_count=len(category_rows),
    )
    session.add(run)
    session.flush()

    for row in category_rows:
        session.add(
            SetlsCategoryStat(
                run_id=run.id,
                code=str(row["code"]),
                description=row.get("description"),  # type: ignore[arg-type]
                current_toys=row.get("current_toys"),  # type: ignore[arg-type]
                total_toys=row.get("total_toys"),  # type: ignore[arg-type]
                pct_share=row.get("pct_share"),  # type: ignore[arg-type]
                reservable=row.get("reservable"),  # type: ignore[arg-type]
                max_renewals=row.get("max_renewals"),  # type: ignore[arg-type]
            )
        )

    for status, count in sorted(status_counts.items(), key=lambda item: (-item[1], item[0])):
        session.add(
            SetlsToyStatusCount(
                run_id=run.id,
                status=status,
                toy_count=count,
            )
        )

    session.flush()
    return run


def latest_setls_import_run(session: Session) -> SetlsImportRun | None:
    return session.scalars(
        select(SetlsImportRun).order_by(SetlsImportRun.imported_at.desc()).limit(1)
    ).first()
