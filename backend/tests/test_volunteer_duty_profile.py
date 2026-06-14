from datetime import date

from app.services.duty_service import split_volunteer_duty_sessions


class _Row:
    def __init__(self, session_date: date) -> None:
        self.session_date = session_date


def test_split_volunteer_duty_sessions() -> None:
    today = date(2026, 6, 10)
    rows = [
        _Row(date(2026, 6, 1)),
        _Row(date(2026, 6, 10)),
        _Row(date(2026, 6, 17)),
    ]
    upcoming, completed = split_volunteer_duty_sessions(rows, today=today)
    assert [row.session_date for row in upcoming] == [date(2026, 6, 10), date(2026, 6, 17)]
    assert [row.session_date for row in completed] == [date(2026, 6, 1)]
