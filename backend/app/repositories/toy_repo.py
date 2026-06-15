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
from sqlalchemy.orm import Session, joinedload

from app.core.availability import member_availability, normalize_availability
from app.core.reservation_hold import (
    format_queue_opens_label,
    pending_queue_blocks_new_booking,
)
from app.db.session import get_engine, session_scope
from app.models.loan import LOAN_STATUS_ACTIVE, Loan
from app.models.toy import Toy as ToyORM
from app.models.toy_image import ToyImage as ToyImageORM
from app.schemas.toy import ToyOut
from app.repositories.loan_repo import get_active_loan_for_toy
from app.repositories.booking_repo import get_pending_booking_for_toy, get_pending_bookings_for_toys
from app.services.pieces_from_setls import (
    ToyPieceLine,
    load_pieces_summary,
    serialize_piece_inventory,
    totals_from_piece_lines,
)
from app.services.rental_price_from_setls import load_rental_prices

_MAX_DISTINCT_AGE_RANGES = 100
_MAX_DISTINCT_MANUFACTURERS = 200

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
    pieces_by_toy = load_pieces_summary()
    rental_by_toy = load_rental_prices()
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        for row in reader:
            toy_id = (row.get("toy_id") or "").strip()
            name = (row.get("toy_name") or "").strip()
            if not toy_id or not name:
                continue
            status = _to_none(row.get("Status"))
            piece_data = pieces_by_toy.get(toy_id)
            total_pieces = piece_data[0] if piece_data else None
            missing_pieces = None
            if piece_data and piece_data[1] > 0:
                missing_pieces = piece_data[1]
            rental_price_cents = rental_by_toy.get(toy_id)
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
                    total_pieces=total_pieces,
                    missing_pieces=missing_pieces,
                    rental_price_cents=rental_price_cents,
                )
            )
    return tuple(toys)


def _db_toy_count() -> int:
    # If DATABASE_URL isn't configured, treat DB as "not available" (count=0).
    return _cached_db_toy_count()


@lru_cache(maxsize=1)
def _cached_db_toy_count() -> int:
    engine = get_engine()
    if engine is None:
        return 0

    session = session_scope()
    try:
        return int(session.scalar(select(func.count()).select_from(ToyORM)) or 0)
    finally:
        session.close()


def invalidate_db_toy_count_cache() -> None:
    _cached_db_toy_count.cache_clear()


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
        total_pieces=toy.total_pieces,
        missing_pieces=toy.missing_pieces,
        missing_pieces_detail=toy.missing_pieces_detail,
        rental_price_cents=toy.rental_price_cents,
    )


def _with_member_availability(
    toy: ToyOut,
    *,
    has_active_loan: bool,
    pending=None,
) -> ToyOut:
    queue_blocked = pending_queue_blocks_new_booking(pending)
    availability = member_availability(
        toy.status,
        has_active_loan=has_active_loan,
        has_pending_booking=queue_blocked,
    )
    updates: dict[str, object] = {}
    if availability != toy.availability:
        updates["availability"] = availability
    queue_opens_label = (
        format_queue_opens_label(pending) if pending is not None else None
    )
    if queue_opens_label != toy.queue_opens_label:
        updates["queue_opens_label"] = queue_opens_label
    if not updates:
        return toy
    return toy.model_copy(update=updates)


def _active_loan_toy_ids(session: Session, toy_ids: list[str]) -> set[str]:
    if not toy_ids:
        return set()
    canonical_by_lower = {tid.lower(): tid for tid in toy_ids}
    rows = session.scalars(
        select(Loan.toy_id).where(
            func.lower(Loan.toy_id).in_(list(canonical_by_lower)),
            Loan.status == LOAN_STATUS_ACTIVE,
        )
    ).all()
    return {
        canonical_by_lower[row.lower()]
        for row in rows
        if row.lower() in canonical_by_lower
    }


def _toy_row_to_member_out(session: Session, toy: ToyORM) -> ToyOut:
    out = _toy_row_to_out(toy)
    pending = get_pending_booking_for_toy(session, toy.toy_id)
    has_loan = get_active_loan_for_toy(session, toy.toy_id) is not None
    return _with_member_availability(
        out,
        has_active_loan=has_loan,
        pending=pending,
    )


def _apply_member_availability_batch(
    session: Session,
    items: list[ToyOut],
) -> list[ToyOut]:
    toy_ids = [item.toy_id for item in items]
    on_loan_ids = _active_loan_toy_ids(session, toy_ids)
    pending_by_toy = get_pending_bookings_for_toys(session, toy_ids)
    return [
        _with_member_availability(
            item,
            has_active_loan=item.toy_id in on_loan_ids,
            pending=pending_by_toy.get(item.toy_id),
        )
        for item in items
    ]


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
            items = _apply_member_availability_batch(
                session,
                [_toy_row_to_out(t) for t in rows],
            )
            items = [item for item in items if item.availability == availability]
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
        return _apply_member_availability_batch(
            session,
            [_toy_row_to_out(t) for t in rows],
        ), total
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


def _next_toy_id(session) -> str:
    """Next numeric toy id (CSV/SETLS ids are mostly digits)."""
    ids = session.scalars(select(ToyORM.toy_id)).all()
    max_num = 0
    for tid in ids:
        stripped = tid.strip()
        if stripped.isdigit():
            max_num = max(max_num, int(stripped))
    return str(max_num + 1)


def create_toy_in_db(
    *,
    name: str,
    category_label: str | None = None,
    age_range: str | None = None,
    status: str | None = "In library",
    manufacturer: str | None = None,
    description: str | None = None,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    rental_price_cents: int | None = None,
) -> ToyOut | None:
    """Insert a new toy row; returns None when the database is not configured."""
    if get_engine() is None:
        return None
    cleaned_name = name.strip()
    if not cleaned_name:
        return None
    _validate_toy_pieces(total_pieces, missing_pieces)
    session = session_scope()
    try:
        toy_id = _next_toy_id(session)
        toy = ToyORM(
            toy_id=toy_id,
            name=cleaned_name,
            category_label=category_label.strip() or None if category_label else None,
            age_range=age_range.strip() or None if age_range else None,
            status=(status or "In library").strip() or "In library",
            manufacturer=manufacturer.strip() or None if manufacturer else None,
            description=description.strip() or None if description else None,
            total_pieces=total_pieces,
            missing_pieces=missing_pieces,
            rental_price_cents=rental_price_cents,
        )
        session.add(toy)
        session.commit()
        session.refresh(toy)
        invalidate_db_toy_count_cache()
        return _toy_row_to_out(toy)
    finally:
        session.close()


def update_toy_in_db(
    toy_id: str,
    *,
    name: str | None = None,
    category_label: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    manufacturer: str | None = None,
    description: str | None = None,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    rental_price_cents: int | None = None,
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
        if total_pieces is not None:
            toy.total_pieces = total_pieces
        if missing_pieces is not None:
            toy.missing_pieces = missing_pieces
        if rental_price_cents is not None:
            toy.rental_price_cents = rental_price_cents
        _validate_toy_pieces(toy.total_pieces, toy.missing_pieces)
        session.commit()
        return _toy_row_to_out(toy)
    finally:
        session.close()


def delete_toy_in_db(toy_id: str) -> bool | None:
    """
    Delete a DB-backed toy row (and cascaded ``toy_images``).

    Returns ``None`` when the database catalog is unavailable, ``False`` when the
    toy is missing. Raises ``ValueError`` when bookings or loans reference the toy.
    """
    if _db_toy_count() == 0:
        return None
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return False

    from app.models.booking import Booking
    from app.models.loan import Loan

    photo_filename: str | None = None
    session = session_scope()
    try:
        toy = session.scalar(
            select(ToyORM)
            .options(joinedload(ToyORM.image))
            .where(ToyORM.toy_id == toy_id_norm)
        )
        if toy is None:
            return False

        booking_refs = (
            session.scalar(
                select(func.count())
                .select_from(Booking)
                .where(Booking.toy_id == toy_id_norm)
            )
            or 0
        )
        loan_refs = (
            session.scalar(
                select(func.count())
                .select_from(Loan)
                .where(Loan.toy_id == toy_id_norm)
            )
            or 0
        )
        if booking_refs > 0 or loan_refs > 0:
            raise ValueError(
                "This toy cannot be deleted because it has booking or loan history."
            )

        if toy.image and toy.image.filename:
            photo_filename = toy.image.filename.strip() or None

        session.delete(toy)
        session.commit()
        invalidate_db_toy_count_cache()
    finally:
        session.close()

    if photo_filename:
        from app.services.supabase_storage import (
            delete_toy_photo,
            toy_photos_storage_enabled,
        )
        from app.services.toy_photo import resolve_toy_images_root

        if toy_photos_storage_enabled():
            delete_toy_photo(photo_filename)
        else:
            root = resolve_toy_images_root()
            if root is not None:
                path = root / photo_filename
                if path.is_file():
                    path.unlink(missing_ok=True)

    return True


def _validate_toy_pieces(total: int | None, missing: int | None) -> None:
    if total is not None and missing is not None and missing > total:
        raise ValueError("missing_pieces cannot exceed total_pieces.")


def _validate_piece_lines(lines: list[ToyPieceLine]) -> None:
    for line in lines:
        if not line.name.strip():
            raise ValueError("Piece name cannot be empty.")
        if line.quantity < 1:
            raise ValueError("Piece quantity must be at least 1.")
        if line.missing < 0 or line.missing > line.quantity:
            raise ValueError("missing cannot exceed quantity for a piece line.")


def get_toy_piece_inventory_raw(toy_id: str) -> str | None:
    """Return stored ``piece_inventory`` JSON for a DB toy, or ``None`` if unavailable."""
    if _db_toy_count() == 0:
        return None
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    session = session_scope()
    try:
        toy = session.get(ToyORM, toy_id_norm)
        if toy is None:
            return None
        return toy.piece_inventory
    finally:
        session.close()


def update_toy_pieces_in_db(
    toy_id: str,
    *,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    piece_lines: list[ToyPieceLine] | None = None,
) -> ToyOut | None:
    """Update piece counts and/or full inventory."""
    if piece_lines is not None:
        if _db_toy_count() == 0:
            return None
        toy_id_norm = toy_id.strip()
        if not toy_id_norm:
            return None
        _validate_piece_lines(piece_lines)
        computed_total, computed_missing = totals_from_piece_lines(piece_lines)
        session = session_scope()
        try:
            toy = session.scalar(
                select(ToyORM)
                .options(joinedload(ToyORM.image))
                .where(ToyORM.toy_id == toy_id_norm)
            )
            if toy is None:
                return None
            toy.piece_inventory = serialize_piece_inventory(piece_lines)
            toy.total_pieces = computed_total
            toy.missing_pieces = computed_missing if computed_missing > 0 else None
            _validate_toy_pieces(toy.total_pieces, toy.missing_pieces)
            session.commit()
            return _toy_row_to_out(toy)
        finally:
            session.close()

    return update_toy_in_db(
        toy_id,
        total_pieces=total_pieces,
        missing_pieces=missing_pieces,
    )


def update_toy_photo_filename_in_db(
    toy_id: str,
    new_filename: str,
) -> tuple[ToyOut | None, str | None]:
    """Upsert ``toy_images.filename`` without writing local files."""
    if _db_toy_count() == 0:
        return None, None
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None, None

    safe_name = Path(new_filename).name
    if not safe_name or safe_name in (".", ".."):
        raise ValueError("Invalid photo filename.")

    session = session_scope()
    try:
        toy = session.scalar(
            select(ToyORM)
            .options(joinedload(ToyORM.image))
            .where(ToyORM.toy_id == toy_id_norm)
        )
        if toy is None:
            return None, None

        old_filename = toy.image.filename if toy.image else None
        if toy.image is None:
            session.add(ToyImageORM(toy_id=toy_id_norm, filename=safe_name))
        else:
            toy.image.filename = safe_name

        session.commit()
        session.refresh(toy)
        return _toy_row_to_out(toy), old_filename
    finally:
        session.close()


def upload_toy_photo_in_db(
    toy_id: str,
    *,
    image_bytes: bytes,
    filename_suffix: str,
    storage_root: Path,
) -> ToyOut | None:
    """Write image file and upsert ``toy_images`` row."""
    if _db_toy_count() == 0:
        return None
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    suffix = filename_suffix if filename_suffix.startswith(".") else f".{filename_suffix}"
    if suffix not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise ValueError("Unsupported image format.")

    new_filename = f"{toy_id_norm}{suffix}"
    storage_root.mkdir(parents=True, exist_ok=True)
    dest = (storage_root / new_filename).resolve()
    root_r = storage_root.resolve()
    if not str(dest).startswith(str(root_r)):
        raise ValueError("Invalid photo filename.")

    session = session_scope()
    try:
        toy = session.scalar(
            select(ToyORM)
            .options(joinedload(ToyORM.image))
            .where(ToyORM.toy_id == toy_id_norm)
        )
        if toy is None:
            return None

        old_filename = toy.image.filename if toy.image else None
        dest.write_bytes(image_bytes)

        if toy.image is None:
            session.add(ToyImageORM(toy_id=toy_id_norm, filename=new_filename))
        else:
            toy.image.filename = new_filename

        session.commit()
        session.refresh(toy)

        if old_filename and old_filename != new_filename:
            from app.services.toy_photo import safe_delete_photo_file

            safe_delete_photo_file(storage_root, old_filename)

        return _toy_row_to_out(toy)
    finally:
        session.close()


def resolve_toy_orm(session, toy_id: str) -> ToyORM | None:
    """Match toy_id case-insensitively (desk loans may send j146 vs J146)."""
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    toy = session.get(ToyORM, toy_id_norm)
    if toy is not None:
        return toy
    return session.scalar(
        select(ToyORM).where(func.lower(ToyORM.toy_id) == toy_id_norm.lower())
    )


def get_toy_detail_from_db(
    session: Session,
    toy_id: str,
) -> tuple[ToyOut, str | None] | None:
    """Load one toy and its raw piece inventory in a single query."""
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    toy = session.scalar(
        select(ToyORM)
        .options(joinedload(ToyORM.image))
        .where(ToyORM.toy_id == toy_id_norm)
    )
    if toy is None:
        toy = resolve_toy_orm(session, toy_id_norm)
    if toy is None:
        return None
    return _toy_row_to_member_out(session, toy), toy.piece_inventory


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
            if toy is None:
                toy = resolve_toy_orm(session, toy_id_norm)
            return _toy_row_to_member_out(session, toy) if toy else None
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


def distinct_manufacturers() -> list[str]:
    """Distinct non-empty ``manufacturer`` values for admin toy forms."""

    def _dedupe_sort(raw_values: list[str]) -> list[str]:
        seen: set[str] = set()
        out: list[str] = []
        for raw in raw_values:
            value = raw.strip()
            if not value:
                continue
            key = value.lower()
            if key in seen:
                continue
            seen.add(key)
            out.append(value)
        out.sort(key=str.lower)
        return out[:_MAX_DISTINCT_MANUFACTURERS]

    if _db_toy_count() > 0:
        session = session_scope()
        try:
            stmt = (
                select(ToyORM.manufacturer)
                .where(ToyORM.manufacturer.is_not(None))
                .where(ToyORM.manufacturer != "")
                .distinct()
            )
            rows = session.scalars(stmt).all()
            return _dedupe_sort([r for r in rows if r is not None])
        finally:
            session.close()

    values = [t.manufacturer for t in load_all_toys() if t.manufacturer]
    return _dedupe_sort(values)
