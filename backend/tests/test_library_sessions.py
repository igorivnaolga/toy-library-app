from datetime import date, datetime
from zoneinfo import ZoneInfo

from app.core.library_sessions import (
    LIBRARY_TIMEZONE,
    allowed_pickup_dates,
    earliest_bookable_date,
    format_pickup_label,
    is_allowed_pickup_date,
    session_end_datetime,
)

TZ = LIBRARY_TIMEZONE


def _dt(y: int, m: int, d: int, hh: int, mm: int = 0) -> datetime:
    return datetime(y, m, d, hh, mm, tzinfo=TZ)


def test_earliest_bookable_same_day_before_session_end() -> None:
    # Wednesday 19 May 2026, 10:00 — session not started yet.
    now = _dt(2026, 5, 19, 10, 0)
    assert earliest_bookable_date(now=now) == date(2026, 5, 19)


def test_earliest_bookable_skips_today_after_session_end() -> None:
    # Wednesday after 2:30 pm → next Saturday.
    now = _dt(2026, 5, 19, 15, 0)
    assert earliest_bookable_date(now=now) == date(2026, 5, 23)


def test_allowed_pickup_dates_four_week_horizon() -> None:
    # Monday 18 May 2026 — horizon through 15 June; Wed/Sat only.
    now = _dt(2026, 5, 18, 9, 0)
    dates = allowed_pickup_dates(now=now)
    assert dates[0] == date(2026, 5, 20)  # Wed
    assert all(d.weekday() in (2, 5) for d in dates)
    assert dates[-1] <= date(2026, 6, 15)
    assert len(dates) >= 7


def test_is_allowed_rejects_non_session_weekday() -> None:
    now = _dt(2026, 5, 18, 9, 0)
    assert is_allowed_pickup_date(date(2026, 5, 21), now=now) is False  # Thursday


def test_format_pickup_label() -> None:
    assert format_pickup_label(date(2026, 5, 20)) == "Wednesday 20 May"


def test_session_end_datetime() -> None:
    end = session_end_datetime(date(2026, 5, 23))
    assert end.hour == 14 and end.minute == 0
