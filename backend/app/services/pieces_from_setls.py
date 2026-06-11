"""Load SETLS piece export and aggregate MVP totals per toy."""

from __future__ import annotations

import csv
import json
from collections import defaultdict
from dataclasses import dataclass
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


@dataclass(frozen=True)
class ToyPieceLine:
    """One SETLS piece line (e.g. 2 H with 1 missing)."""

    name: str
    quantity: int
    missing: int = 0


def _piece_line_sort_key(line: ToyPieceLine) -> tuple[int, str]:
    lowered = line.name.casefold()
    if lowered == "contents card":
        return (2, lowered)
    if "instruction" in lowered:
        return (1, lowered)
    return (0, lowered)


def aggregate_piece_lines_for_toy(
    rows: list[dict[str, str]],
    toy_id: str,
) -> list[ToyPieceLine]:
    """Group SETLS export rows into display lines for one toy."""
    tid = toy_id.strip()
    if not tid:
        return []

    tallies: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for row in rows:
        row_tid = (row.get("Toy ID") or row.get("toy_id") or "").strip()
        if row_tid != tid:
            continue
        name = (row.get("Name") or row.get("name") or "").strip()
        if not name:
            continue
        qty = _parse_quantity(row.get("Quantity"))
        if qty <= 0:
            continue
        if _is_soft_deleted(row.get("Soft deleted?")):
            tallies[name][1] += qty
        else:
            tallies[name][0] += qty

    lines: list[ToyPieceLine] = []
    for name, (present, missing) in tallies.items():
        total = present + missing
        if total <= 0:
            continue
        lines.append(ToyPieceLine(name=name, quantity=total, missing=missing))

    lines.sort(key=_piece_line_sort_key)
    return lines


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


@lru_cache(maxsize=1)
def _load_piece_lines_by_toy() -> dict[str, list[ToyPieceLine]]:
    if not _PIECES_CSV.is_file():
        return {}

    with _PIECES_CSV.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    toy_ids = {
        (row.get("Toy ID") or row.get("toy_id") or "").strip()
        for row in rows
    }
    toy_ids.discard("")
    return {
        toy_id: aggregate_piece_lines_for_toy(rows, toy_id)
        for toy_id in toy_ids
    }


def load_piece_lines_for_toy(toy_id: str) -> list[ToyPieceLine]:
    """Return SETLS piece breakdown for a catalog toy id."""
    return list(_load_piece_lines_by_toy().get(toy_id.strip(), []))


def parse_piece_inventory_json(raw: str | None) -> list[ToyPieceLine] | None:
    """Parse DB ``piece_inventory`` JSON; ``None`` means use SETLS fallback."""
    if raw is None:
        return None
    text = raw.strip()
    if not text:
        return None
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, list):
        return None
    lines: list[ToyPieceLine] = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        name = (item.get("name") or "").strip()
        quantity = _parse_quantity(item.get("quantity"))
        missing = _parse_quantity(item.get("missing"))
        if not name or quantity <= 0:
            continue
        if missing > quantity:
            missing = quantity
        lines.append(ToyPieceLine(name=name, quantity=quantity, missing=missing))
    lines.sort(key=_piece_line_sort_key)
    return lines


def serialize_piece_inventory(lines: list[ToyPieceLine]) -> str:
    """Persist editable inventory to ``toys.piece_inventory``."""
    payload = [
        {"name": line.name, "quantity": line.quantity, "missing": line.missing}
        for line in lines
    ]
    return json.dumps(payload, separators=(",", ":"))


def totals_from_piece_lines(lines: list[ToyPieceLine]) -> tuple[int, int]:
    total = sum(line.quantity for line in lines)
    missing = sum(line.missing for line in lines)
    return total, missing


def resolve_piece_lines_for_toy(
    toy_id: str,
    *,
    piece_inventory: str | None = None,
) -> list[ToyPieceLine]:
    """DB inventory overrides SETLS export when present."""
    stored = parse_piece_inventory_json(piece_inventory)
    if stored is not None:
        return stored
    return load_piece_lines_for_toy(toy_id)


def format_piece_line(line: ToyPieceLine) -> str:
    """Human-readable quantity + name (missing shown separately in the app)."""
    return f"{line.quantity} {line.name}"
