"""Two-week reservation hold before another member may queue the same toy."""

from __future__ import annotations

from datetime import date, datetime

from app.core.library_sessions import (
    LIBRARY_TIMEZONE,
    first_session_after_reservation_hold,
    format_pickup_label,
    library_now,
)
from app.models.loan import DEFAULT_LOAN_DAYS


def reservation_day_from_pending(pending) -> date | None:
    """Calendar day the existing reservation was created (library timezone)."""
    created_at = getattr(pending, "created_at", None)
    if not isinstance(created_at, datetime):
        return None
    return created_at.astimezone(LIBRARY_TIMEZONE).date()


def reservation_hold_opens_on(pending) -> date | None:
    """First open session when another member may book this toy."""
    reservation_day = reservation_day_from_pending(pending)
    if reservation_day is None:
        return None
    return first_session_after_reservation_hold(
        reservation_day,
        hold_days=DEFAULT_LOAN_DAYS,
    )


def pending_queue_blocks_new_booking(
    pending,
    *,
    now: datetime | None = None,
) -> bool:
    """True while the two-week hold from an existing reservation is still active."""
    if pending is None:
        return False
    opens_on = reservation_hold_opens_on(pending)
    if opens_on is None:
        return True
    now = now or library_now()
    return now.date() < opens_on


def format_queue_opens_label(pending) -> str | None:
    opens_on = reservation_hold_opens_on(pending)
    if opens_on is None:
        return None
    return format_pickup_label(opens_on)
