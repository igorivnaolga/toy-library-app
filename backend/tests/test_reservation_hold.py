"""Tests for two-week reservation queue holds."""

from datetime import date, datetime

from app.core.library_sessions import LIBRARY_TIMEZONE
from app.core.reservation_hold import (
    pending_queue_blocks_new_booking,
    reservation_hold_opens_on,
)


def _dt(y: int, m: int, d: int) -> datetime:
    return datetime(y, m, d, 12, 0, tzinfo=LIBRARY_TIMEZONE)


def test_pending_queue_blocks_during_two_week_hold() -> None:
    pending = type(
        "Pending",
        (),
        {"created_at": _dt(2026, 6, 8)},
    )()
    assert reservation_hold_opens_on(pending) == date(2026, 6, 24)
    assert pending_queue_blocks_new_booking(
        pending,
        now=_dt(2026, 6, 8),
    )
    assert pending_queue_blocks_new_booking(
        pending,
        now=_dt(2026, 6, 23),
    )


def test_pending_queue_opens_after_hold_session() -> None:
    pending = type(
        "Pending",
        (),
        {"created_at": _dt(2026, 6, 8)},
    )()
    assert not pending_queue_blocks_new_booking(
        pending,
        now=_dt(2026, 6, 24),
    )
