"""Church Corner Toy Library open sessions (Wed/Sat) and pickup-date rules."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

# Pacific/Auckland — library location (Upper Riccarton, Christchurch).
LIBRARY_TIMEZONE = ZoneInfo("Pacific/Auckland")

# Python weekday(): Monday=0 … Sunday=6.
LIBRARY_WEEKDAYS = frozenset({2, 5})  # Wednesday, Saturday

MAX_PICKUP_MONTHS_AHEAD = 6

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


def first_session_on_or_after(day: date) -> date:
    """First Wed/Sat library session on or after ``day`` (return date / due date)."""
    probe = day
    for _ in range(366):
        if is_library_session_day(probe):
            return probe
        probe += timedelta(days=1)
    raise ValueError(f"No library session within a year after {day.isoformat()}.")


def first_session_after_anchor(anchor_day: date) -> date:
    """First bookable session after an anchor day (never the anchor if it is a session)."""
    anchor_session = first_session_on_or_after(anchor_day)
    if anchor_session == anchor_day:
        return first_session_on_or_after(anchor_day + timedelta(days=1))
    return anchor_session


def first_session_after_loan_due(due_date: date) -> date:
    """First bookable session after a loan ends."""
    return first_session_after_anchor(due_date)


def first_session_after_reservation_hold(
    reservation_day: date,
    *,
    hold_days: int,
) -> date:
    """First bookable session after the reservation hold period (e.g. two weeks)."""
    return first_session_after_anchor(reservation_day + timedelta(days=hold_days))


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


def add_calendar_months(day: date, months: int) -> date:
    """Add whole calendar months, clamping the day when the target month is shorter."""
    import calendar

    month_index = day.month - 1 + months
    year = day.year + month_index // 12
    month = month_index % 12 + 1
    last_day = calendar.monthrange(year, month)[1]
    return date(year, month, min(day.day, last_day))


def bookable_horizon_end(from_day: date) -> date:
    """Last calendar day in the booking window starting at ``from_day``."""
    return add_calendar_months(from_day, MAX_PICKUP_MONTHS_AHEAD)


def latest_bookable_date(*, now: datetime | None = None) -> date:
    """Last calendar day in the booking horizon (6 months from today)."""
    now = now or library_now()
    return bookable_horizon_end(now.date())


def session_pickup_dates_between(start: date, end: date) -> list[date]:
    """Wed/Sat session dates from ``start`` through ``end`` inclusive."""
    dates: list[date] = []
    probe = start
    while probe <= end:
        if is_library_session_day(probe):
            dates.append(probe)
        probe += timedelta(days=1)
    return dates


def allowed_pickup_dates(*, now: datetime | None = None) -> list[date]:
    """Wed/Sat session dates from earliest bookable through the 6-month horizon."""
    now = now or library_now()
    start = earliest_bookable_date(now=now)
    end = latest_bookable_date(now=now)
    return session_pickup_dates_between(start, end)


def is_allowed_pickup_date(pickup_date: date, *, now: datetime | None = None) -> bool:
    if not is_library_session_day(pickup_date):
        return False
    allowed = allowed_pickup_dates(now=now)
    return pickup_date in allowed


def format_pickup_label(pickup_date: date) -> str:
    """Human label, e.g. ``Wednesday 21 May``."""
    return pickup_date.strftime("%A %d %B")
