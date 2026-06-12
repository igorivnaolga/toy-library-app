"""SETLS catalog CSV parsing for statistics import."""

from __future__ import annotations

from pathlib import Path

from app.services.setls_import_service import (
    CATEGORIES_CSV,
    TOYS_LIST_CSV,
    read_setls_category_rows,
    read_setls_toy_status_counts,
)


def test_read_setls_category_rows_from_repo_export() -> None:
    if not CATEGORIES_CSV.is_file():
        return
    rows = read_setls_category_rows()
    assert len(rows) >= 10
    codes = {str(row["code"]) for row in rows}
    assert "Preschool" in codes
    assert "Baby" in codes


def test_read_setls_toy_status_counts_from_repo_export() -> None:
    if not TOYS_LIST_CSV.is_file():
        return
    counts = read_setls_toy_status_counts()
    assert sum(counts.values()) >= 1000
    assert "In library" in counts
