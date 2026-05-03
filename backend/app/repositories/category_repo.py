import csv
from pathlib import Path

from sqlalchemy import func, select

from app.db.session import get_engine, session_scope
from app.models.category import Category as CategoryORM
from app.repositories.toy_repo import load_all_toys
from app.schemas.category import CategoryOut
from app.utils.csv_text import (
    clean_cell,
    get_norm,
    norm_match_key,
    row_normalized,
    sanitize_header,
    slug_from_label,
    to_optional_bool,
    to_optional_int,
)

CATEGORIES_CSV = (
    Path(__file__).resolve().parents[3] / "export_imgs" / "Toys-categories.csv"
)


def _db_category_count() -> int:
    engine = get_engine()
    if engine is None:
        return 0

    session = session_scope()
    try:
        return int(session.scalar(select(func.count()).select_from(CategoryORM)) or 0)
    finally:
        session.close()


def _list_categories_db() -> list[CategoryOut]:
    session = session_scope()
    try:
        rows = session.scalars(
            select(CategoryORM).order_by(func.lower(CategoryORM.label).asc())
        ).all()
        return [
            CategoryOut(
                code=c.code,
                label=c.label,
                max_renewals=c.max_renewals,
                reservable=c.reservable,
                toy_count_current=c.toy_count_current,
                toy_count_total=c.toy_count_total,
                pct=c.pct_label,
            )
            for c in rows
        ]
    finally:
        session.close()


def _load_category_metadata_rows() -> tuple[dict[str, dict[str, str]], list[dict[str, str]]]:
    """
    Return:
    - by_label_key: Toys-categories row mapped by normalized `Description`
    - rows_raw: parsed rows preserving original CSV keys
    """
    if not CATEGORIES_CSV.exists():
        return {}, []

    with CATEGORIES_CSV.open("r", encoding="utf-8-sig", newline="") as csv_file:
        rows_raw = list(csv.DictReader(csv_file))

    by_description: dict[str, dict[str, str]] = {}
    for row in rows_raw:
        rn = row_normalized(row)
        desc = rn.get(sanitize_header("Description"))
        if not desc:
            continue
        by_description.setdefault(norm_match_key(desc), row)

    return by_description, rows_raw


def list_categories() -> list[CategoryOut]:
    if _db_category_count() > 0:
        return _list_categories_db()

    toy_category_labels = {
        toy.category.strip()
        for toy in load_all_toys()
        if toy.category and toy.category.strip()
    }

    csv_by_desc, csv_rows_raw = _load_category_metadata_rows()

    csv_by_code: dict[str, dict[str, str]] = {}
    for row in csv_rows_raw:
        rn = row_normalized(row)
        code_val = rn.get(sanitize_header("Code"))
        if code_val:
            csv_by_code.setdefault(norm_match_key(code_val), row)

    categories: dict[str, CategoryOut] = {}

    for label in sorted(toy_category_labels, key=lambda s: s.lower()):
        label_norm = norm_match_key(label)
        csv_row = csv_by_desc.get(label_norm)

        if not csv_row and ":" in label:
            prefix, rest = label.split(":", 1)
            prefix_key = norm_match_key(prefix.strip())
            rest_norm = norm_match_key(rest)
            candidate = csv_by_code.get(prefix_key)
            rn_candidate = (
                row_normalized(candidate)
                if candidate
                else {}
            )
            desc_candidate = rn_candidate.get(sanitize_header("Description"))
            if (
                candidate
                and desc_candidate
                and norm_match_key(desc_candidate) == rest_norm
            ):
                csv_row = candidate
            elif candidate and not desc_candidate:
                csv_row = candidate

        rn = row_normalized(csv_row) if csv_row else {}
        csv_code = clean_cell(get_norm(rn, "Code"))
        code = csv_code or slug_from_label(label) or label_norm.upper()

        max_renewals = (
            to_optional_int(
                get_norm(rn, "Max # renewals", "Maxrenewals")
            )
            if csv_row
            else None
        )
        reservable = (
            to_optional_bool(get_norm(rn, "Reservable?", "Reservable"))
            if csv_row
            else None
        )
        toy_count_current = (
            to_optional_int(
                get_norm(
                    rn,
                    "# of current toys",
                    "ofcurrenttoys",
                )
            )
            if csv_row
            else None
        )
        toy_count_total = (
            to_optional_int(
                get_norm(
                    rn,
                    "# of total toys",
                    "oftotaltoys",
                )
            )
            if csv_row
            else None
        )
        pct_raw = (
            clean_cell(
                get_norm(
                    rn,
                    "%",
                    "pct",
                    "percent",
                    "percentage",
                )
            )
            if csv_row
            else None
        )

        categories[label] = CategoryOut(
            code=code,
            label=label,
            max_renewals=max_renewals,
            reservable=reservable,
            toy_count_current=toy_count_current,
            toy_count_total=toy_count_total,
            pct=pct_raw,
        )

    dedup_codes: dict[str, int] = {}
    finalized: list[CategoryOut] = []
    for category in sorted(categories.values(), key=lambda c: c.label.lower()):
        code = category.code.strip()
        if not code:
            code = slug_from_label(category.label)
        dup_count = dedup_codes.get(code, 0)
        if dup_count:
            code = f"{code}_{dup_count + 1}"
        dedup_codes[code] = dup_count + 1
        finalized.append(category.model_copy(update={"code": code}))

    return finalized
