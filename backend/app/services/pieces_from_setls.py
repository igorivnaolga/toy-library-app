"""Load SETLS piece export and aggregate MVP totals per toy."""

from __future__ import annotations

import csv
from collections import defaultdict
from functools import lru_cache
from pathlib import Path

_PIECES_CSV = (
    Path(__file__).resolve().parents[3]
    / "export_imgs"
    / "setls_pieces_export.csv"
)
_SUMMARY_CSV = (
    Path(__file__).resolve().parents[3]
    / "export_imgs"
    / "toy_pieces_summary.csv"
)


def _parse_quantity(raw: str | None) -> int:
    if raw is None:
        return 0
    text = str(raw).strip()
    if not text:
        return 0
    try:
        return max(0, int(text))
    except ValueError:
        return 0


def _is_soft_deleted(raw: str | None) -> bool:
    return (raw or "").strip().lower() in {"yes", "y", "true", "1"}


def aggregate_pieces_rows(
    rows: list[dict[str, str]],
) -> dict[str, tuple[int, int]]:
    """
    Return toy_id -> (total_pieces, missing_pieces).

    total_pieces: sum of Quantity across all piece lines (full cataloged set).
    missing_pieces: sum of Quantity where Soft deleted? is Yes.
    """
    totals: dict[str, int] = defaultdict(int)
    missing: dict[str, int] = defaultdict(int)

    for row in rows:
        toy_id = (row.get("Toy ID") or row.get("toy_id") or "").strip()
        if not toy_id:
            continue
        qty = _parse_quantity(row.get("Quantity"))
        totals[toy_id] += qty
        if _is_soft_deleted(row.get("Soft deleted?")):
            missing[toy_id] += qty

    return {
        toy_id: (totals[toy_id], missing[toy_id])
        for toy_id in totals
    }


@lru_cache(maxsize=1)
def load_pieces_summary() -> dict[str, tuple[int, int]]:
    """Read pre-built summary CSV if present, else aggregate SETLS export."""
    if _SUMMARY_CSV.is_file():
        out: dict[str, tuple[int, int]] = {}
        with _SUMMARY_CSV.open(encoding="utf-8-sig", newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                toy_id = (row.get("toy_id") or "").strip()
                if not toy_id:
                    continue
                total = _parse_quantity(row.get("total_pieces"))
                miss = _parse_quantity(row.get("missing_pieces"))
                out[toy_id] = (total, miss)
        return out

    if not _PIECES_CSV.is_file():
        return {}

    with _PIECES_CSV.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    return aggregate_pieces_rows(rows)


def write_pieces_summary_csv(
    path: Path | None = None,
    *,
    source: Path | None = None,
) -> Path:
    """Aggregate SETLS export and write toy_pieces_summary.csv."""
    src = source or _PIECES_CSV
    out_path = path or _SUMMARY_CSV
    if not src.is_file():
        raise FileNotFoundError(f"Missing SETLS pieces export: {src}")

    with src.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    summary = aggregate_pieces_rows(rows)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["toy_id", "toy_name", "total_pieces", "missing_pieces"],
        )
        writer.writeheader()
        names: dict[str, str] = {}
        for row in rows:
            tid = (row.get("Toy ID") or "").strip()
            if tid and tid not in names:
                names[tid] = (row.get("Toy name") or "").strip()
        for toy_id in sorted(summary, key=lambda x: (len(x), x)):
            total, miss = summary[toy_id]
            writer.writerow(
                {
                    "toy_id": toy_id,
                    "toy_name": names.get(toy_id, ""),
                    "total_pieces": total,
                    "missing_pieces": miss,
                }
            )
    return out_path
