from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.category import Category
from app.models.toy import Toy
from app.models.toy_image import ToyImage
from app.repositories.category_repo import list_categories as build_categories_from_csv
from app.repositories.toy_repo import load_all_toys


def seed_catalog(session: Session) -> tuple[int, int]:
    """
    Upsert categories + toys + primary toy image filename from seed CSVs.

    Returns:
        (categories_upserted, toys_upserted)
    """
    category_rows = build_categories_from_csv()
    label_to_id: dict[str, uuid.UUID] = {}

    categories_upserted = 0
    for row in category_rows:
        existing = session.scalar(select(Category).where(Category.label == row.label))
        if existing:
            existing.code = row.code
            existing.max_renewals = row.max_renewals
            existing.reservable = row.reservable
            existing.toy_count_current = row.toy_count_current
            existing.toy_count_total = row.toy_count_total
            existing.pct_label = row.pct
            category_id = existing.id
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
            session.flush()
            category_id = created.id
            categories_upserted += 1

        label_to_id[row.label] = category_id

    toys_upserted = 0
    for t in load_all_toys():
        category_id = None
        if t.category and t.category.strip():
            category_id = label_to_id.get(t.category.strip())

        toy_row = session.get(Toy, t.toy_id)
        if toy_row:
            toy_row.name = t.name
            toy_row.category_id = category_id
            toy_row.age_range = t.age_range
            toy_row.status = t.status
            toy_row.manufacturer = t.manufacturer
            toy_row.description = t.description
            toy_row.category_label = t.category
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
            )
            session.add(toy_row)
            session.flush()
            toys_upserted += 1

        if t.photo_file:
            if toy_row.image:
                toy_row.image.filename = t.photo_file
            else:
                session.add(ToyImage(toy_id=toy_row.toy_id, filename=t.photo_file))

    session.commit()
    return categories_upserted, toys_upserted
