from __future__ import annotations

import uuid

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.toy import Toy
from app.models.toy_image import ToyImage
from app.repositories.category_repo import list_categories_csv
from app.repositories.toy_repo import load_all_toys
from app.services.pieces_from_setls import load_pieces_summary


_TOY_BATCH_SIZE = 100


def seed_catalog(session: Session) -> tuple[int, int]:
    """
    Upsert categories + toys + primary toy image filename from seed CSVs.

    Returns:
        (categories_upserted, toys_upserted)
    """
    # Supabase pooler default can cancel long statements; seeding ~1k rows needs headroom.
    session.execute(text("SET LOCAL statement_timeout = '600s'"))

    # Always derive seed rows from CSV exports (even if DB already has categories).
    category_rows = list_categories_csv()
    # Map the human-facing category label (what toys store in `category_label`) to the
    # UUID primary key in `categories.id` (what toys store in `category_id`).
    label_to_id: dict[str, uuid.UUID] = {}

    categories_upserted = 0
    for row in category_rows:
        # Upsert by label first; fall back to unique `code` for idempotent re-runs.
        existing = session.scalar(select(Category).where(Category.label == row.label))
        if existing is None and row.code:
            existing = session.scalar(select(Category).where(Category.code == row.code))
        if existing:
            existing.code = row.code
            existing.max_renewals = row.max_renewals
            existing.reservable = row.reservable
            existing.toy_count_current = row.toy_count_current
            existing.toy_count_total = row.toy_count_total
            existing.pct_label = row.pct
        else:
            created = Category(
                code=row.code,
                label=row.label,
                max_renewals=row.max_renewals,
                reservable=row.reservable,
                toy_count_current=row.toy_count_current,
                toy_count_total=row.toy_count_total,
                pct_label=row.pct,
            )
            session.add(created)
            categories_upserted += 1

    session.flush()
    for row in category_rows:
        category = session.scalar(select(Category).where(Category.label == row.label))
        if category is not None:
            label_to_id[row.label] = category.id
    session.commit()

    toys_upserted = 0
    rows_in_batch = 0
    session.execute(text("SET LOCAL statement_timeout = '600s'"))
    pieces_by_toy = load_pieces_summary()
    for t in load_all_toys():
        category_id = None
        if t.category and t.category.strip():
            # `t.category` is expected to match `Category.label` exactly (seed CSVs aligned).
            category_id = label_to_id.get(t.category.strip())

        toy_row = session.get(Toy, t.toy_id)
        piece_data = pieces_by_toy.get(t.toy_id)
        piece_total = piece_data[0] if piece_data else None
        piece_missing = piece_data[1] if piece_data else None
        missing_value = piece_missing if piece_missing and piece_missing > 0 else None
        if toy_row:
            toy_row.name = t.name
            toy_row.category_id = category_id
            toy_row.age_range = t.age_range
            toy_row.status = t.status
            toy_row.manufacturer = t.manufacturer
            toy_row.description = t.description
            toy_row.category_label = t.category
            if piece_total is not None:
                toy_row.total_pieces = piece_total
                toy_row.missing_pieces = missing_value
        else:
            toy_row = Toy(
                toy_id=t.toy_id,
                name=t.name,
                category_id=category_id,
                age_range=t.age_range,
                status=t.status,
                manufacturer=t.manufacturer,
                description=t.description,
                category_label=t.category,
                total_pieces=piece_total,
                missing_pieces=missing_value,
            )
            session.add(toy_row)
            toys_upserted += 1

        rows_in_batch += 1

        if t.photo_file:
            # MVP: one image row per toy (`toy_images.toy_id` is unique).
            if toy_row.image:
                toy_row.image.filename = t.photo_file
            else:
                session.add(ToyImage(toy_id=toy_row.toy_id, filename=t.photo_file))

        if rows_in_batch >= _TOY_BATCH_SIZE:
            session.commit()
            session.execute(text("SET LOCAL statement_timeout = '600s'"))
            rows_in_batch = 0

    session.commit()
    return categories_upserted, toys_upserted
