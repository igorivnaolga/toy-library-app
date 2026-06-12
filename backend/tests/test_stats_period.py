"""Statistics period resolution."""

from __future__ import annotations

from datetime import date

import pytest

from app.services.stats_period import StatsPeriodError, resolve_stats_period


def test_resolve_month_defaults_to_today() -> None:
    period = resolve_stats_period(period="month", now=date(2026, 6, 8))
    assert period.kind == "month"
    assert period.start == date(2026, 6, 1)
    assert period.end == date(2026, 6, 30)
    assert period.label == "June 2026"


def test_resolve_session_wednesday() -> None:
    session_day = date(2026, 6, 10)  # Wednesday
    period = resolve_stats_period(period="session", session_date=session_day)
    assert period.start == session_day
    assert period.end == session_day


def test_resolve_session_rejects_non_session_day() -> None:
    with pytest.raises(StatsPeriodError):
        resolve_stats_period(period="session", session_date=date(2026, 6, 9))


def test_resolve_year() -> None:
    period = resolve_stats_period(period="year", year=2025)
    assert period.start == date(2025, 1, 1)
    assert period.end == date(2025, 12, 31)


def test_resolve_all_has_no_bounds() -> None:
    period = resolve_stats_period(period="all")
    assert period.start is None
    assert period.end is None
