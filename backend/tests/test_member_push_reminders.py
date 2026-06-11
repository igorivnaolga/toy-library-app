from datetime import datetime
from zoneinfo import ZoneInfo

from app.core.library_sessions import LIBRARY_TIMEZONE
from app.services.member_push_reminders import (
    EVE_REMINDER_HOUR,
    MORNING_REMINDER_HOUR,
    OVERDUE_REMINDER_HOUR,
    _active_reminder_slot,
)


def test_active_reminder_slot_eve() -> None:
    now = datetime(2026, 6, 3, EVE_REMINDER_HOUR, 10, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "eve"


def test_active_reminder_slot_morning() -> None:
    now = datetime(2026, 6, 4, MORNING_REMINDER_HOUR, 5, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "morning"


def test_active_reminder_slot_overdue() -> None:
    now = datetime(2026, 6, 4, OVERDUE_REMINDER_HOUR, 15, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "overdue"


def test_active_reminder_slot_outside_window() -> None:
    now = datetime(2026, 6, 4, 12, 0, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) is None
