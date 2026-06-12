"""Statistics overview period semantics."""

from __future__ import annotations

from datetime import date

from app.services.stats_period import resolve_stats_period
from app.services.stats_service import ToyPopularityRow, _on_or_before_period_end_filter


def test_members_end_filter_for_year() -> None:
    period = resolve_stats_period(period="year", year=2024)
    clause, params = _on_or_before_period_end_filter("u.created_at", period)
    assert "<= :end_date" in clause
    assert params["end_date"] == date(2024, 12, 31)


def test_members_end_filter_all_time_has_no_clause() -> None:
    period = resolve_stats_period(period="all")
    clause, params = _on_or_before_period_end_filter("u.created_at", period)
    assert clause == ""
    assert params == {}


def test_toy_popularity_row_shape() -> None:
    row = ToyPopularityRow(toy_id="100", name="Duplo set", count=12)
    assert row.toy_id == "100"
    assert row.count == 12
