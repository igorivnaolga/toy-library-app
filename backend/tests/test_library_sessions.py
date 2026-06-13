from datetime import date, datetime, time
from zoneinfo import ZoneInfo

from app.core.library_sessions import (
    LIBRARY_TIMEZONE,
    allowed_pickup_dates,
    duty_desk_opens_at,
    earliest_bookable_date,
    first_session_after_loan_due,
    first_session_after_reservation_hold,
    first_session_on_or_after,
    format_pickup_label,
    is_allowed_pickup_date,
    is_within_duty_desk_window,
    session_end_datetime,
    loan_return_deadline,
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


def test_allowed_pickup_dates_six_month_horizon() -> None:
    # Monday 18 May 2026 — horizon through 18 November; Wed/Sat only.
    now = _dt(2026, 5, 18, 9, 0)
    dates = allowed_pickup_dates(now=now)
    assert dates[0] == date(2026, 5, 20)  # Wed
    assert all(d.weekday() in (2, 5) for d in dates)
    assert dates[-1] <= date(2026, 11, 18)
    assert len(dates) >= 40


def test_is_allowed_rejects_non_session_weekday() -> None:
    now = _dt(2026, 5, 18, 9, 0)
    assert is_allowed_pickup_date(date(2026, 5, 21), now=now) is False  # Thursday


def test_format_pickup_label() -> None:
    assert format_pickup_label(date(2026, 5, 20)) == "Wednesday 20 May"


def test_session_end_datetime() -> None:
    end = session_end_datetime(date(2026, 5, 23))
    assert end.hour == 14 and end.minute == 0


def test_first_session_on_or_after_due_on_wednesday() -> None:
    assert first_session_on_or_after(date(2026, 5, 20)) == date(2026, 5, 20)


def test_first_session_on_or_after_due_on_friday() -> None:
    assert first_session_on_or_after(date(2026, 5, 22)) == date(2026, 5, 23)


def test_first_session_after_loan_due_on_session_day() -> None:
    # Saturday due date → next Wednesday, not the same Saturday.
    assert first_session_after_loan_due(date(2026, 7, 11)) == date(2026, 7, 15)


def test_first_session_after_loan_due_before_next_session() -> None:
    # Friday due date → following Saturday session.
    assert first_session_after_loan_due(date(2026, 7, 10)) == date(2026, 7, 11)


def test_first_session_after_reservation_hold() -> None:
    # Reserved Monday 8 June → first pickup from Wednesday 24 June.
    assert first_session_after_reservation_hold(
        date(2026, 6, 8),
        hold_days=14,
    ) == date(2026, 6, 24)


def test_loan_return_deadline_on_session_due_date() -> None:
    from datetime import datetime

    deadline = loan_return_deadline(date(2026, 5, 20))
    assert deadline == datetime(2026, 5, 20, 14, 30, tzinfo=TZ)


def test_loan_return_deadline_after_non_session_due_date() -> None:
    from datetime import datetime

    deadline = loan_return_deadline(date(2026, 5, 22))  # Friday → Saturday
    assert deadline == datetime(2026, 5, 23, 14, 0, tzinfo=TZ)


def test_duty_desk_opens_thirty_minutes_before_session() -> None:
    assert duty_desk_opens_at(time(13, 0)) == time(12, 30)
    assert is_within_duty_desk_window(time(13, 0), time(14, 30), time(12, 30))
    assert not is_within_duty_desk_window(time(13, 0), time(14, 30), time(12, 29))
    assert is_within_duty_desk_window(time(13, 0), time(14, 30), time(14, 0))
