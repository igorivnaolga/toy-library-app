"""Duty roster business rules."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.library_sessions import SESSION_END, SESSION_START, is_library_session_day
from app.models.duty_session import DutySession
from app.core.library_sessions import library_now
from app.repositories.duty_repo import (
    claim_duty_session,
    confirm_duty_session,
    insert_missing_duty_sessions,
    list_duty_sessions,
)
from app.repositories.profile_repo import get_profile_by_id
from app.services.payment_service import grant_volunteer_duty_credit


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


def duty_booking_milestone_message(booked_count: int) -> str | None:
    """Optional thank-you copy when a volunteer reaches a booking milestone."""
    if booked_count != 3:
        return None
    return (
        "You've booked your third volunteer shift — thank you! "
        "Your time makes a real difference at the toy library. "
        "You're very welcome to book more sessions whenever you'd like; "
        "any extra help is always appreciated."
    )


# Auto-created roster window (matches the mobile roster's scroll limits).
ROSTER_PAST_DAYS = 365
ROSTER_FUTURE_DAYS = 365 * 2


def ensure_roster_sessions(
    session: Session,
    *,
    from_date: date,
    to_date: date,
    today: date | None = None,
) -> None:
    """
    Create open Wed/Sat rows for missing session days in range.

    Only days within ``ROSTER_PAST_DAYS``/``ROSTER_FUTURE_DAYS`` of today are
    created, so callers cannot make the roster grow without bound.
    """
    today = today or library_now().date()
    start = max(from_date, today - timedelta(days=ROSTER_PAST_DAYS))
    end = min(to_date, today + timedelta(days=ROSTER_FUTURE_DAYS))
    if end < start:
        return
    existing_days = {
        row.session_date
        for row in list_duty_sessions(session, from_date=start, to_date=end)
    }
    missing = [
        (day, SESSION_START[day.weekday()], SESSION_END[day.weekday()])
        for day in iter_library_session_dates(start, end)
        if day not in existing_days
    ]
    insert_missing_duty_sessions(session, missing)


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
    if row.volunteer_id is not None or not claim_duty_session(session, row.id, user_id):
        raise DutyError(
            "slot_already_assigned",
            "This slot already has a volunteer assigned.",
        )
    session.refresh(row)
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
    # Lock the slot so two admins confirming at once grant the credit only once.
    session.refresh(row, with_for_update=True)
    if row.volunteer_id is None:
        raise DutyError("slot_unbooked", "No volunteer is booked for this duty slot.")
    if row.session_date != library_now().date():
        raise DutyError(
            "not_duty_day",
            "Duty can only be confirmed on the day of the shift.",
        )
    if row.admin_confirmed_at is not None:
        return row
    confirmed = confirm_duty_session(session, row, admin_id)
    grant_volunteer_duty_credit(session, confirmed, recorded_by=admin_id)
    return confirmed


def split_volunteer_duty_sessions(
    rows: list[DutySession],
    *,
    today: date | None = None,
) -> tuple[list[DutySession], list[DutySession]]:
    """Upcoming (asc) and completed (newest first) booked shifts."""
    today = today or library_now().date()
    upcoming = [row for row in rows if row.session_date >= today]
    completed = [row for row in rows if row.session_date < today]
    completed.reverse()
    return upcoming, completed
