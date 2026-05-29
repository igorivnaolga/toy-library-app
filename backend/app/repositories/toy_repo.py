"""
Toy catalog data access.

This module supports a deliberate migration path:

1) Early project stage: read toys from the committed CSV export.
2) After you seed Postgres: read toys from the `toys` table.

Why: lets you keep the API working before Supabase is configured, while still
moving to a real database once `DATABASE_URL` is set and data is imported.
"""

import csv
from functools import lru_cache
from pathlib import Path

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import joinedload

from app.core.availability import normalize_availability
from app.db.session import get_engine, session_scope
from app.models.toy import Toy as ToyORM
from app.schemas.toy import ToyOut

_MAX_DISTINCT_AGE_RANGES = 100

# Canonical seed export used by early development + the CSV->DB import script.
CSV_PATH = (
    Path(__file__).resolve().parents[3]
    / "export_imgs"
    / "toy_photo_map_by_description.csv"
)


def _to_none(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    return value or None


@lru_cache(maxsize=1)
def load_all_toys() -> tuple[ToyOut, ...]:
    # Memoized parse: CSV reads are fast but repeated work in seed + CSV fallback.
    if not CSV_PATH.exists():
        return ()

    toys: list[ToyOut] = []
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            toy_id = (row.get("toy_id") or "").strip()
            name = (row.get("toy_name") or "").strip()
            if not toy_id or not name:
                continue
            status = _to_none(row.get("Status"))
            toys.append(
                ToyOut(
                    toy_id=toy_id,
                    name=name,
                    category=_to_none(row.get("Category")),
                    age_range=_to_none(row.get("Age Range")),
                    status=status,
                    availability=normalize_availability(status),
                    manufacturer=_to_none(row.get("Manufacturer")),
                    description=_to_none(row.get("description")),
                    photo_file=_to_none(row.get("photo_file_desc")),
                )
            )
    return tuple(toys)


def _db_toy_count() -> int:
    # If DATABASE_URL isn't configured, treat DB as "not available" (count=0).
    engine = get_engine()
    if engine is None:
        return 0

    session = session_scope()
    try:
        return int(session.scalar(select(func.count()).select_from(ToyORM)) or 0)
    finally:
        session.close()


def _toy_row_to_out(toy: ToyORM) -> ToyOut:
    # Map ORM row -> API DTO. `category` stays the human-facing label string because
    # Flutter filters currently pass the full label (same as CSV-era behavior).
    photo_file = toy.image.filename if toy.image else None
    status = toy.status
    return ToyOut(
        toy_id=toy.toy_id,
        name=toy.name,
        category=toy.category_label,
        age_range=toy.age_range,
        status=status,
        availability=normalize_availability(status),
        manufacturer=toy.manufacturer,
        description=toy.description,
        photo_file=photo_file,
    )


def _list_toys_db(
    page: int = 1,
    limit: int = 20,
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    availability: str | None = None,
) -> tuple[list[ToyOut], int]:
    session = session_scope()
    try:
        # Build SQL filters incrementally. When `filters` is empty, `where(*filters)`
        # becomes "no WHERE clause" (valid in SQLAlchemy 2.x).
        filters = []

        if q:
            q_norm = f"%{q.strip().lower()}%"
            filters.append(
                or_(
                    func.lower(ToyORM.toy_id).like(q_norm),
                    # Case-insensitive substring search on name.
                    func.lower(ToyORM.name).like(q_norm),
                    and_(
                        # Avoid `lower(NULL)` patterns; descriptions may be missing.
                        ToyORM.description.is_not(None),
                        func.lower(ToyORM.description).like(q_norm),
                    ),
                )
            )

        if category:
            category_norm = category.strip().lower()
            filters.append(func.lower(ToyORM.category_label) == category_norm)

        if age_range:
            age_norm = age_range.strip().lower()
            filters.append(func.lower(ToyORM.age_range) == age_norm)

        if status:
            status_norm = status.strip().lower()
            filters.append(func.lower(ToyORM.status) == status_norm)

        stmt = (
            select(ToyORM)
            # Eager-load image row so `_toy_row_to_out` doesn't trigger N+1 queries.
            .options(joinedload(ToyORM.image))
            .where(*filters)
            .order_by(ToyORM.toy_id.asc())
        )

        if availability:
            # Availability is currently derived from `status`, not stored as its own
            # DB column. Filter after mapping rows so DB and CSV behavior stay aligned.
            rows = session.scalars(stmt).unique().all()
            items = [
                item
                for item in (_toy_row_to_out(t) for t in rows)
                if item.availability == availability
            ]
            total = len(items)
            start = (page - 1) * limit
            end = start + limit
            return items[start:end], total

        # Count uses the same predicates, but without ORDER/OFFSET/LIMIT.
        count_stmt = select(func.count()).select_from(ToyORM).where(*filters)
        total = int(session.scalar(count_stmt) or 0)

        start = (page - 1) * limit
        # `.unique()` is recommended when using joined eager loads that can duplicate
        # parent rows in the result set (defensive; cheap for one-to-one image).
        rows = session.scalars(stmt.offset(start).limit(limit)).unique().all()
        return [_toy_row_to_out(t) for t in rows], total
    finally:
        session.close()


def list_toys(
    page: int = 1,
    limit: int = 20,
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    availability: str | None = None,
) -> tuple[list[ToyOut], int]:
    # DB-first once we have any toy rows imported; otherwise keep CSV behavior.
    if _db_toy_count() > 0:
        return _list_toys_db(
            page=page,
            limit=limit,
            q=q,
            category=category,
            age_range=age_range,
            status=status,
            availability=availability,
        )

    items = list(load_all_toys())

    if q:
        q_norm = q.strip().lower()
        items = [
            toy
            for toy in items
            if q_norm in toy.toy_id.lower()
            or q_norm in toy.name.lower()
            or (toy.description and q_norm in toy.description.lower())
        ]

    if category:
        category_norm = category.strip().lower()
        items = [
            toy
            for toy in items
            if toy.category and toy.category.lower() == category_norm
        ]

    if age_range:
        age_norm = age_range.strip().lower()
        items = [
            toy
            for toy in items
            if toy.age_range and toy.age_range.lower() == age_norm
        ]

    if status:
        status_norm = status.strip().lower()
        items = [
            toy for toy in items if toy.status and toy.status.lower() == status_norm
        ]

    if availability:
        items = [toy for toy in items if toy.availability == availability]

    total = len(items)
    start = (page - 1) * limit
    end = start + limit
    return items[start:end], total


def update_toy_in_db(
    toy_id: str,
    *,
    name: str | None = None,
    category_label: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    manufacturer: str | None = None,
    description: str | None = None,
) -> ToyOut | None:
    """Update a DB-backed toy row; returns None when catalog is CSV-only or toy missing."""
    if _db_toy_count() == 0:
        return None
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    session = session_scope()
    try:
        toy = session.scalar(
            select(ToyORM)
            .options(joinedload(ToyORM.image))
            .where(ToyORM.toy_id == toy_id_norm)
        )
        if toy is None:
            return None
        if name is not None:
            cleaned = name.strip()
            if cleaned:
                toy.name = cleaned
        if category_label is not None:
            toy.category_label = category_label.strip() or None
        if age_range is not None:
            toy.age_range = age_range.strip() or None
        if status is not None:
            toy.status = status.strip() or None
        if manufacturer is not None:
            toy.manufacturer = manufacturer.strip() or None
        if description is not None:
            toy.description = description.strip() or None
        session.commit()
        return _toy_row_to_out(toy)
    finally:
        session.close()


def get_toy_by_id(toy_id: str) -> ToyOut | None:
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None

    # Same DB-first rule as list endpoint.
    if _db_toy_count() > 0:
        session = session_scope()
        try:
            toy = session.scalar(
                select(ToyORM)
                .options(joinedload(ToyORM.image))
                .where(ToyORM.toy_id == toy_id_norm)
            )
            return _toy_row_to_out(toy) if toy else None
        finally:
            session.close()

    for toy in load_all_toys():
        if toy.toy_id == toy_id_norm:
            return toy
    return None


def distinct_age_ranges() -> list[str]:
    """
    Distinct non-empty ``age_range`` values for filter UI.

    DB path matches ``list_toys`` DB-first rule. CSV path derives from the same
    export as ``load_all_toys``. Values are de-duplicated case-insensitively,
    sorted case-insensitively, capped at ``_MAX_DISTINCT_AGE_RANGES``.
    """

    def _dedupe_sort(raw_values: list[str]) -> list[str]:
        seen: set[str] = set()
        out: list[str] = []
        for raw in raw_values:
            ar = raw.strip()
            if not ar:
                continue
            key = ar.lower()
            if key in seen:
                continue
            seen.add(key)
            out.append(ar)
        out.sort(key=str.lower)
        return out[:_MAX_DISTINCT_AGE_RANGES]

    if _db_toy_count() > 0:
        session = session_scope()
        try:
            stmt = (
                select(ToyORM.age_range)
                .where(ToyORM.age_range.is_not(None))
                .where(ToyORM.age_range != "")
                .distinct()
            )
            rows = session.scalars(stmt).all()
            return _dedupe_sort([r for r in rows if r is not None])
        finally:
            session.close()

    values = [t.age_range for t in load_all_toys() if t.age_range]
    return _dedupe_sort(values)
