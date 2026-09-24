from datetime import datetime

from app.core.library_sessions import LIBRARY_TIMEZONE
from app.services.member_push_reminders import (
    DUTY_EVE_REMINDER_HOUR,
    EVE_REMINDER_HOUR,
    MORNING_REMINDER_HOUR,
    _active_reminder_slot,
)


def test_active_reminder_slot_eve() -> None:
    now = datetime(2026, 6, 3, EVE_REMINDER_HOUR, 10, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "eve"


def test_active_reminder_slot_duty_eve() -> None:
    now = datetime(2026, 6, 3, DUTY_EVE_REMINDER_HOUR, 10, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "duty_eve"


def test_active_reminder_slot_morning() -> None:
    now = datetime(2026, 6, 4, MORNING_REMINDER_HOUR, 5, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) == "morning"


def test_active_reminder_slot_outside_window() -> None:
    now = datetime(2026, 6, 4, 12, 0, tzinfo=LIBRARY_TIMEZONE)
    assert _active_reminder_slot(now) is None


def test_cron_schedule_hits_every_slot_in_nzst_and_nzdt() -> None:
    """The GitHub cron UTC hours must reach all three NZ slots in both DST seasons."""
    import re
    from datetime import datetime, timezone
    from pathlib import Path
    from zoneinfo import ZoneInfo

    from app.services.member_push_reminders import _active_reminder_slot

    workflow = (
        Path(__file__).resolve().parents[2] / ".github" / "workflows" / "member-reminders-cron.yml"
    ).read_text(encoding="utf-8")
    minute, hours = re.search(r'cron: "(\d+) ([\d,]+) \* \* \*"', workflow).groups()

    for day in (datetime(2026, 7, 15), datetime(2026, 12, 15)):  # NZST, NZDT
        slots = set()
        for hour in hours.split(","):
            utc = day.replace(hour=int(hour), minute=int(minute), tzinfo=timezone.utc)
            slots.add(_active_reminder_slot(utc.astimezone(ZoneInfo("Pacific/Auckland"))))
        assert {"duty_eve", "eve", "morning"} <= slots, (day, slots)
