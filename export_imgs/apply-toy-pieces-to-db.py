"""
Apply toy_pieces_summary.csv to Postgres (run from repo root).

Same as:
  cd backend && python -m app.scripts.apply_pieces_from_csv
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ROOT = REPO_ROOT / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.scripts.apply_pieces_from_csv import main  # noqa: E402

if __name__ == "__main__":
    main()
