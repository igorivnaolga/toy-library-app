"""
Aggregate SETLS piece export into toy_pieces_summary.csv.

Input (default): export_imgs/setls_pieces_export.csv
  Columns: Quantity, Name, Soft deleted?, Toy ID, Toy name

Output: export_imgs/toy_pieces_summary.csv
  Columns: toy_id, toy_name, total_pieces, missing_pieces

Workflow:
  1) Export from SETLS: Reports → Pieces for current items (save CSV)
  2) Save/copy as export_imgs/setls_pieces_export.csv
  3) python export_imgs/build-toy-pieces-summary.py
  4) python export_imgs/apply-toy-pieces-to-db.py
     (or: cd backend && python -m app.scripts.apply_pieces_from_csv)
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPO_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.pieces_from_setls import (  # noqa: E402
    _PIECES_CSV,
    _SUMMARY_CSV,
    load_pieces_summary,
    write_pieces_summary_csv,
)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Build toy_pieces_summary.csv from SETLS export.")
    parser.add_argument(
        "--input",
        type=Path,
        default=_PIECES_CSV,
        help="SETLS pieces export CSV",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=_SUMMARY_CSV,
        help="Aggregated summary CSV",
    )
    args = parser.parse_args()

    out = write_pieces_summary_csv(args.output, source=args.input)
    summary = load_pieces_summary()
    with_missing = sum(1 for _, (_, m) in summary.items() if m > 0)
    print(f"Wrote {out}")
    print(f"Toys with piece data: {len(summary)}")
    print(f"Toys with missing pieces: {with_missing}")


if __name__ == "__main__":
    main()
