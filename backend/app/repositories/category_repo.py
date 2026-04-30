import csv
import re
from pathlib import Path

from app.repositories.toy_repo import load_all_toys
from app.schemas.category import CategoryOut

CATEGORIES_CSV = (
    Path(__file__).resolve().parents[3] / "export_imgs" / "Toys-categories.csv"
)


def _clean(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip().strip('"').strip("'")
    return value or None


def _to_optional_int(value: str | None) -> int | None:
    value = _clean(value)
    if value is None:
        return None
    try:
        return int(float(value))
    except ValueError:
        return None


def _to_optional_bool(value: str | None) -> bool | None:
    value = _clean(value)
    if value is None:
        return None
    normalized = value.lower()
    if normalized in {"yes", "y", "true", "1"}:
        return True
    if normalized in {"no", "n", "false", "0"}:
        return False
    return None


def _slug_from_label(label: str) -> str:
    trimmed = label.strip()
    trimmed = trimmed.split(":")[0].strip() if trimmed else ""
    slug = re.sub(r"[^A-Za-z0-9]+", "_", trimmed).strip("_").upper()
    return slug[:32]


def _norm_match_key(label: str) -> str:
    label = label.strip().lower()
    label = label.replace("\\", "/")
    label = re.sub(r"\s+", " ", label)
    return label


def _sanitize_header(header: str) -> str:
    raw = header.strip().strip('"').strip("'")
    lowered = raw.lower()
    if lowered in {"%", "pct", "percentage"}:
        return "pct"

    header = lowered
    header = header.replace("&", " and ")
    header = header.replace("+", "")
    header = header.replace(",", "")
    header = re.sub(r"[^a-z0-9]+", "", header)
    return header


def _row_normalized(row: dict[str, str | None]) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, raw in row.items():
        key_norm = _sanitize_header(str(key))
        clean = _clean(raw if raw is not None else None)
        if not key_norm or clean is None:
            continue
        out[key_norm] = clean
    return out


def _get_norm(row_norm: dict[str, str], *candidates: str) -> str | None:
    for candidate in candidates:
        key_norm = _sanitize_header(candidate)
        if key_norm in row_norm:
            return row_norm[key_norm]
    return None


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
        rn = _row_normalized(row)
        desc = rn.get(_sanitize_header("Description"))
        if not desc:
            continue
        by_description.setdefault(_norm_match_key(desc), row)

    return by_description, rows_raw


def list_categories() -> list[CategoryOut]:
    toy_category_labels = {
        toy.category.strip()
        for toy in load_all_toys()
        if toy.category and toy.category.strip()
    }

    csv_by_desc, csv_rows_raw = _load_category_metadata_rows()

    csv_by_code: dict[str, dict[str, str]] = {}
    for row in csv_rows_raw:
        rn = _row_normalized(row)
        code_val = rn.get(_sanitize_header("Code"))
        if code_val:
            csv_by_code.setdefault(_norm_match_key(code_val), row)

    categories: dict[str, CategoryOut] = {}

    for label in sorted(toy_category_labels, key=lambda s: s.lower()):
        label_norm = _norm_match_key(label)
        csv_row = csv_by_desc.get(label_norm)

        if not csv_row and ":" in label:
            prefix, rest = label.split(":", 1)
            prefix_key = _norm_match_key(prefix.strip())
            rest_norm = _norm_match_key(rest)
            candidate = csv_by_code.get(prefix_key)
            rn_candidate = (
                _row_normalized(candidate)
                if candidate
                else {}
            )
            desc_candidate = rn_candidate.get(_sanitize_header("Description"))
            if (
                candidate
                and desc_candidate
                and _norm_match_key(desc_candidate) == rest_norm
            ):
                csv_row = candidate
            elif candidate and not desc_candidate:
                csv_row = candidate

        rn = _row_normalized(csv_row) if csv_row else {}
        csv_code = _clean(_get_norm(rn, "Code"))
        code = csv_code or _slug_from_label(label) or label_norm.upper()

        max_renewals = (
            _to_optional_int(
                _get_norm(rn, "Max # renewals", "Maxrenewals")
            )
            if csv_row
            else None
        )
        reservable = (
            _to_optional_bool(_get_norm(rn, "Reservable?", "Reservable"))
            if csv_row
            else None
        )
        toy_count_current = (
            _to_optional_int(
                _get_norm(
                    rn,
                    "# of current toys",
                    "ofcurrenttoys",
                )
            )
            if csv_row
            else None
        )
        toy_count_total = (
            _to_optional_int(
                _get_norm(
                    rn,
                    "# of total toys",
                    "oftotaltoys",
                )
            )
            if csv_row
            else None
        )
        pct_raw = (
            _clean(
                _get_norm(
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
            code = _slug_from_label(category.label)
        dup_count = dedup_codes.get(code, 0)
        if dup_count:
            code = f"{code}_{dup_count + 1}"
        dedup_codes[code] = dup_count + 1
        finalized.append(category.model_copy(update={"code": code}))

    return finalized
