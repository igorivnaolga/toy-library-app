import csv
from functools import lru_cache
from pathlib import Path

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


def list_toys(
    page: int = 1,
    limit: int = 20,
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
) -> tuple[list[ToyOut], int]:
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

    for toy in load_all_toys():
        if toy.toy_id == toy_id_norm:
            return toy
    return None
