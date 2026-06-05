"""Load SETLS rental prices per catalog toy_id."""

from __future__ import annotations

import csv
import re
from functools import lru_cache
from pathlib import Path

_RENTAL_CSV = (
    Path(__file__).resolve().parents[3]
    / "export_imgs"
    / "setls_rental_prices.csv"
)

_DOLLAR_RE = re.compile(r"^\$?([0-9]+(?:\.[0-9]{1,2})?)$")


def _parse_dollars_to_cents(raw: str | None) -> int | None:
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    match = _DOLLAR_RE.match(text)
    if not match:
        return None
    dollars = float(match.group(1))
    if dollars < 0:
        return None
    return int(round(dollars * 100))


@lru_cache(maxsize=1)
def load_rental_prices() -> dict[str, int]:
    """Return toy_id -> rental_price_cents from pre-built CSV."""
    if not _RENTAL_CSV.is_file():
        return {}

    out: dict[str, int] = {}
    with _RENTAL_CSV.open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            toy_id = (row.get("toy_id") or "").strip()
            if not toy_id:
                continue
            cents_raw = (row.get("rental_price_cents") or "").strip()
            if cents_raw.isdigit():
                out[toy_id] = int(cents_raw)
                continue
            cents = _parse_dollars_to_cents(row.get("rental_price"))
            if cents is not None:
                out[toy_id] = cents
    return out
