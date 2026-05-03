import csv
from functools import lru_cache
from pathlib import Path

from sqlalchemy import func, or_, select
from sqlalchemy.orm import joinedload

from app.db.session import get_engine, session_scope
from app.models.toy import Toy as ToyORM
from app.schemas.toy import ToyOut

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
            toys.append(
                ToyOut(
                    toy_id=toy_id,
                    name=name,
                    category=_to_none(row.get("Category")),
                    age_range=_to_none(row.get("Age Range")),
                    status=_to_none(row.get("Status")),
                    manufacturer=_to_none(row.get("Manufacturer")),
                    description=_to_none(row.get("description")),
                    photo_file=_to_none(row.get("photo_file_desc")),
                )
            )
    return tuple(toys)


def _db_toy_count() -> int:
    engine = get_engine()
    if engine is None:
        return 0

    session = session_scope()
    try:
        return int(session.scalar(select(func.count()).select_from(ToyORM)) or 0)
    finally:
        session.close()


def _toy_row_to_out(toy: ToyORM) -> ToyOut:
    photo_file = toy.image.filename if toy.image else None
    return ToyOut(
        toy_id=toy.toy_id,
        name=toy.name,
        category=toy.category_label,
        age_range=toy.age_range,
        status=toy.status,
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
) -> tuple[list[ToyOut], int]:
    session = session_scope()
    try:
        filters = []

        if q:
            q_norm = f"%{q.strip().lower()}%"
            filters.append(
                or_(
                    func.lower(ToyORM.name).like(q_norm),
                    and_(
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
            .options(joinedload(ToyORM.image))
            .where(*filters)
            .order_by(ToyORM.toy_id.asc())
        )

        count_stmt = select(func.count()).select_from(ToyORM).where(*filters)
        total = int(session.scalar(count_stmt) or 0)

        start = (page - 1) * limit
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
) -> tuple[list[ToyOut], int]:
    if _db_toy_count() > 0:
        return _list_toys_db(
            page=page,
            limit=limit,
            q=q,
            category=category,
            age_range=age_range,
            status=status,
        )

    items = list(load_all_toys())

    if q:
        q_norm = q.strip().lower()
        items = [
            toy
            for toy in items
            if q_norm in toy.name.lower()
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

    total = len(items)
    start = (page - 1) * limit
    end = start + limit
    return items[start:end], total


def get_toy_by_id(toy_id: str) -> ToyOut | None:
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None

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
