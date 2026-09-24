"""Fail when the repo-root Dockerfile drifts from backend/Dockerfile.

The root file must equal backend/Dockerfile with a ``backend/`` prefix on COPY
sources (comment header aside). Run from the repo root: python scripts/check_dockerfiles_in_sync.py
"""

from __future__ import annotations

import sys
from pathlib import Path


def _body(text: str) -> list[str]:
    lines = text.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("FROM "))
    return lines[start:]


def _unprefixed(line: str) -> str:
    if not line.startswith("COPY "):
        return line
    parts = line.split(" ")
    sources = [p.removeprefix("backend/") for p in parts[1:-1]]
    return " ".join([parts[0], *sources, parts[-1]])


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    backend = _body((root / "backend" / "Dockerfile").read_text(encoding="utf-8"))
    repo = [_unprefixed(line) for line in _body((root / "Dockerfile").read_text(encoding="utf-8"))]
    if backend != repo:
        import difflib

        print("Dockerfile drift (backend/Dockerfile vs root Dockerfile):")
        print("\n".join(difflib.unified_diff(backend, repo, lineterm="")))
        return 1
    print("Dockerfiles in sync.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
