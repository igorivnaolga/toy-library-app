"""Church Corner Toy Library open sessions (Wed/Sat) and pickup-date rules."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

# Pacific/Auckland — library location (Upper Riccarton, Christchurch).
LIBRARY_TIMEZONE = ZoneInfo("Pacific/Auckland")

# Python weekday(): Monday=0 … Sunday=6.
LIBRARY_WEEKDAYS = frozenset({2, 5})  # Wednesday, Saturday

MAX_PICKUP_WEEKS_AHEAD = 4
MAX_PICKUP_DAYS_AHEAD = MAX_PICKUP_WEEKS_AHEAD * 7

# Session times from organisation opening hours (local time).
SESSION_START: dict[int, time] = {
    2: time(13, 0),  # Wed 1:00 pm
    5: time(11, 30),  # Sat 11:30 am
}
SESSION_END: dict[int, time] = {
    2: time(14, 30),  # Wed 2:30 pm
    5: time(14, 0),  # Sat 2:00 pm
}


def library_now() -> datetime:
    return datetime.now(LIBRARY_TIMEZONE)


def is_library_session_day(day: date) -> bool:
    return day.weekday() in LIBRARY_WEEKDAYS


def session_end_datetime(pickup_date: date) -> datetime:
    """End of the pickup window on a library session day (timezone-aware)."""
    weekday = pickup_date.weekday()
    if weekday not in SESSION_END:
        raise ValueError(f"{pickup_date.isoformat()} is not a library session day.")
    return datetime.combine(pickup_date, SESSION_END[weekday], tzinfo=LIBRARY_TIMEZONE)


def earliest_bookable_date(*, now: datetime | None = None) -> date:
    """
    First session day a member may choose when booking now.

    Same-day is allowed while that session's pickup window has not ended.
    """
    now = now or library_now()
    today = now.date()
    weekday = today.weekday()
    if weekday in LIBRARY_WEEKDAYS and now.timetz() < SESSION_END[weekday]:
        return today

    probe = today + timedelta(days=1)
    while not is_library_session_day(probe):
        probe += timedelta(days=1)
    return probe


def latest_bookable_date(*, now: datetime | None = None) -> date:
    """Last calendar day in the booking horizon (4 weeks from today)."""
    now = now or library_now()
    return now.date() + timedelta(days=MAX_PICKUP_DAYS_AHEAD)


def allowed_pickup_dates(*, now: datetime | None = None) -> list[date]:
    """Wed/Sat session dates from earliest bookable through the 4-week horizon."""
    now = now or library_now()
    start = earliest_bookable_date(now=now)
    end = latest_bookable_date(now=now)
    dates: list[date] = []
    probe = start
    while probe <= end:
        if is_library_session_day(probe):
            dates.append(probe)
        probe += timedelta(days=1)
    return dates


def is_allowed_pickup_date(pickup_date: date, *, now: datetime | None = None) -> bool:
    if not is_library_session_day(pickup_date):
        return False
    allowed = allowed_pickup_dates(now=now)
    return pickup_date in allowed


def format_pickup_label(pickup_date: date) -> str:
    """Human label, e.g. ``Wednesday 21 May``."""
    return pickup_date.strftime("%A %d %B")
