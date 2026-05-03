from __future__ import annotations

import re


def clean_cell(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip().strip('"').strip("'")
    return value or None


def to_optional_int(value: str | None) -> int | None:
    value = clean_cell(value)
    if value is None:
        return None
    try:
        return int(float(value))
    except ValueError:
        return None


def to_optional_bool(value: str | None) -> bool | None:
    value = clean_cell(value)
    if value is None:
        return None
    normalized = value.lower()
    if normalized in {"yes", "y", "true", "1"}:
        return True
    if normalized in {"no", "n", "false", "0"}:
        return False
    return None


def slug_from_label(label: str) -> str:
    trimmed = label.strip()
    trimmed = trimmed.split(":")[0].strip() if trimmed else ""
    slug = re.sub(r"[^A-Za-z0-9]+", "_", trimmed).strip("_").upper()
    return slug[:32]


def norm_match_key(label: str) -> str:
    label = label.strip().lower()
    label = label.replace("\\", "/")
    label = re.sub(r"\s+", " ", label)
    return label


def sanitize_header(header: str) -> str:
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


def row_normalized(row: dict[str, str | None]) -> dict[str, str]:
    out: dict[str, str] = {}
    for key, raw in row.items():
        key_norm = sanitize_header(str(key))
        clean = clean_cell(raw if raw is not None else None)
        if not key_norm or clean is None:
            continue
        out[key_norm] = clean
    return out


def get_norm(row_norm: dict[str, str], *candidates: str) -> str | None:
    for candidate in candidates:
        key_norm = sanitize_header(candidate)
        if key_norm in row_norm:
            return row_norm[key_norm]
    return None
