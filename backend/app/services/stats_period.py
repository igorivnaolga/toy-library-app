"""Resolve admin statistics period filters to date ranges."""

from __future__ import annotations

import calendar
from dataclasses import dataclass
from datetime import date

from app.core.library_sessions import is_library_session_day, library_now

StatsPeriodKind = str  # session | month | year | all


@dataclass(frozen=True)
class StatsPeriod:
    kind: StatsPeriodKind
    start: date | None
    end: date | None
    label: str


class StatsPeriodError(ValueError):
    pass


def _month_bounds(year: int, month: int) -> tuple[date, date]:
    if month < 1 or month > 12:
        raise StatsPeriodError("month must be 1–12.")
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, 1), date(year, month, last_day)


def resolve_stats_period(
    *,
    period: StatsPeriodKind,
    session_date: date | None = None,
    year: int | None = None,
    month: int | None = None,
    now: date | None = None,
) -> StatsPeriod:
    """Map query params to an inclusive local-date range in Pacific/Auckland."""
    today = now or library_now().date()
    normalized = (period or "month").strip().lower()

    if normalized == "all":
        return StatsPeriod(kind="all", start=None, end=None, label="All time")

    if normalized == "session":
        if session_date is None:
            raise StatsPeriodError("session_date is required for period=session.")
        if not is_library_session_day(session_date):
            raise StatsPeriodError(
                f"{session_date.isoformat()} is not a library session day (Wed/Sat)."
            )
        label = session_date.strftime("%A %d %b %Y")
        return StatsPeriod(
            kind="session",
            start=session_date,
            end=session_date,
            label=label,
        )

    if normalized == "month":
        y = year if year is not None else today.year
        m = month if month is not None else today.month
        start, end = _month_bounds(y, m)
        label = start.strftime("%B %Y")
        return StatsPeriod(kind="month", start=start, end=end, label=label)

    if normalized == "year":
        y = year if year is not None else today.year
        start = date(y, 1, 1)
        end = date(y, 12, 31)
        return StatsPeriod(kind="year", start=start, end=end, label=str(y))

    raise StatsPeriodError("period must be session, month, year, or all.")
