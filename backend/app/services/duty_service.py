"""Duty roster business rules."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.library_sessions import SESSION_END, SESSION_START, is_library_session_day
from app.models.duty_session import DutySession
from app.core.library_sessions import library_now
from app.repositories.duty_repo import (
    confirm_duty_session,
    create_duty_session,
    list_duty_sessions,
)
from app.repositories.profile_repo import get_profile_by_id


class DutyError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def iter_library_session_dates(from_date: date, to_date: date) -> list[date]:
    days: list[date] = []
    probe = from_date
    while probe <= to_date:
        if is_library_session_day(probe):
            days.append(probe)
        probe += timedelta(days=1)
    return days


def ensure_roster_sessions(
    session: Session,
    *,
    from_date: date,
    to_date: date,
) -> list[DutySession]:
    """Return Wed/Sat slots in range, creating open rows for missing session days."""
    existing = list_duty_sessions(session, from_date=from_date, to_date=to_date)
    by_date = {row.session_date: row for row in existing}
    roster: list[DutySession] = []
    for day in iter_library_session_dates(from_date, to_date):
        row = by_date.get(day)
        if row is None:
            weekday = day.weekday()
            row = create_duty_session(
                session,
                session_date=day,
                start_time=SESSION_START[weekday],
                end_time=SESSION_END[weekday],
            )
        roster.append(row)
    session.flush()
    roster.sort(key=lambda item: (item.session_date, item.start_time))
    return roster


def assign_volunteer_to_session(
    session: Session,
    row: DutySession,
    user_id: uuid.UUID,
) -> DutySession:
    profile = get_profile_by_id(session, user_id)
    if profile is None:
        raise DutyError("profile_not_found", "Member not found.")
    if profile.role not in {"member", "volunteer", "admin"}:
        raise DutyError(
            "invalid_assignee",
            "Only members or volunteers can be assigned to duty.",
        )
    if row.volunteer_id is not None:
        raise DutyError(
            "slot_already_assigned",
            "This slot already has a volunteer assigned.",
        )
    row.volunteer_id = user_id
    session.flush()
    return row


def clear_session_assignment(session: Session, row: DutySession) -> DutySession:
    row.volunteer_id = None
    row.admin_confirmed_at = None
    row.admin_confirmed_by = None
    session.flush()
    return row


def confirm_duty_session_for_admin(
    session: Session,
    row: DutySession,
    admin_id: uuid.UUID,
) -> DutySession:
    if row.volunteer_id is None:
        raise DutyError("slot_unbooked", "No volunteer is booked for this duty slot.")
    if row.session_date != library_now().date():
        raise DutyError(
            "not_duty_day",
            "Duty can only be confirmed on the day of the shift.",
        )
    if row.admin_confirmed_at is not None:
        return row
    return confirm_duty_session(session, row, admin_id)
