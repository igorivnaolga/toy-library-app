"""Data access for ``public.duty_sessions``."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time

from sqlalchemy import func, select
from sqlalchemy.orm import Session, joinedload

from app.core.library_sessions import is_within_duty_desk_window, library_now
from app.models.duty_session import DutySession


def list_duty_sessions(
    session: Session,
    *,
    from_date: date,
    to_date: date,
) -> list[DutySession]:
    return list(
        session.scalars(
            select(DutySession)
            .options(joinedload(DutySession.volunteer))
            .where(
                DutySession.session_date >= from_date,
                DutySession.session_date <= to_date,
            )
            .order_by(DutySession.session_date, DutySession.start_time)
        ).all()
    )


def list_duty_dates_in_range(
    session: Session,
    *,
    from_date: date,
    to_date: date,
) -> list[date]:
    rows = session.execute(
        select(DutySession.session_date)
        .where(DutySession.session_date >= from_date)
        .where(DutySession.session_date <= to_date)
        .distinct()
        .order_by(DutySession.session_date.asc())
    ).all()
    return [row[0] for row in rows]


def get_duty_session_by_id(
    session: Session,
    session_id: uuid.UUID,
) -> DutySession | None:
    return session.scalar(
        select(DutySession)
        .options(joinedload(DutySession.volunteer))
        .where(DutySession.id == session_id)
    )


def create_duty_session(
    session: Session,
    *,
    session_date: date,
    start_time: time,
    end_time: time,
    volunteer_id: uuid.UUID | None = None,
) -> DutySession:
    row = DutySession(
        session_date=session_date,
        start_time=start_time,
        end_time=end_time,
        volunteer_id=volunteer_id,
    )
    session.add(row)
    session.flush()
    return row


def count_volunteer_duty_bookings(
    session: Session,
    volunteer_id: uuid.UUID,
) -> int:
    """All duty slots currently or previously booked by this volunteer."""
    return int(
        session.scalar(
            select(func.count())
            .select_from(DutySession)
            .where(DutySession.volunteer_id == volunteer_id)
        )
        or 0
    )


def count_completed_duty_sessions(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    today: date | None = None,
) -> int:
    """Past booked shifts (session day before today in library TZ)."""
    today = today or library_now().date()
    return int(
        session.scalar(
            select(func.count())
            .select_from(DutySession)
            .where(
                DutySession.volunteer_id == volunteer_id,
                DutySession.session_date < today,
            )
        )
        or 0
    )


def list_volunteer_booked_duty_sessions(
    session: Session,
    volunteer_id: uuid.UUID,
) -> list[DutySession]:
    """All duty slots booked by this volunteer, oldest first."""
    return list(
        session.scalars(
            select(DutySession)
            .where(DutySession.volunteer_id == volunteer_id)
            .order_by(DutySession.session_date, DutySession.start_time)
        ).all()
    )


def delete_duty_session(session: Session, row: DutySession) -> None:
    session.delete(row)
    session.flush()


def book_duty_session(
    session: Session,
    row: DutySession,
    volunteer_id: uuid.UUID,
) -> DutySession:
    row.volunteer_id = volunteer_id
    session.flush()
    return row


def cancel_duty_booking(session: Session, row: DutySession) -> DutySession:
    row.volunteer_id = None
    row.admin_confirmed_at = None
    row.admin_confirmed_by = None
    session.flush()
    return row


def _booked_slots_for_volunteer_on_day(
    session: Session,
    volunteer_id: uuid.UUID,
    day: date,
) -> list[DutySession]:
    return list(
        session.scalars(
            select(DutySession).where(
                DutySession.session_date == day,
                DutySession.volunteer_id == volunteer_id,
            )
        ).all()
    )


def volunteer_has_booked_slot_today(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> bool:
    """True when the volunteer has any booked duty slot today."""
    now = now or library_now()
    return (
        session.scalar(
            select(DutySession.id)
            .where(
                DutySession.session_date == now.date(),
                DutySession.volunteer_id == volunteer_id,
            )
            .limit(1)
        )
        is not None
    )


def is_volunteer_on_duty_now(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> bool:
    """True from 30 minutes before session start through session end (library TZ)."""
    now = now or library_now()
    today = now.date()
    current_time = now.timetz().replace(tzinfo=None)
    for row in _booked_slots_for_volunteer_on_day(session, volunteer_id, today):
        if is_within_duty_desk_window(row.start_time, row.end_time, current_time):
            return True
    return False


def volunteer_has_active_slot_now(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> bool:
    """Alias kept for auth error messaging."""
    return is_volunteer_on_duty_now(session, volunteer_id, now=now)


def get_active_duty_session_for_volunteer(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> DutySession | None:
    now = now or library_now()
    today = now.date()
    current_time = now.timetz().replace(tzinfo=None)
    for row in _booked_slots_for_volunteer_on_day(session, volunteer_id, today):
        if is_within_duty_desk_window(row.start_time, row.end_time, current_time):
            return session.scalar(
                select(DutySession)
                .options(joinedload(DutySession.volunteer))
                .where(DutySession.id == row.id)
            )
    return None


def confirm_duty_session(
    session: Session,
    row: DutySession,
    admin_id: uuid.UUID,
    *,
    confirmed_at: datetime | None = None,
) -> DutySession:
    row.admin_confirmed_at = confirmed_at or library_now()
    row.admin_confirmed_by = admin_id
    session.flush()
    return row


def list_todays_unconfirmed_duty_sessions(
    session: Session,
    *,
    today: date | None = None,
) -> list[DutySession]:
    today = today or library_now().date()
    return list(
        session.scalars(
            select(DutySession)
            .options(joinedload(DutySession.volunteer))
            .where(
                DutySession.session_date == today,
                DutySession.volunteer_id.is_not(None),
                DutySession.admin_confirmed_at.is_(None),
            )
            .order_by(DutySession.start_time)
        ).all()
    )


def count_todays_unconfirmed_duty_sessions(session: Session) -> int:
    today = library_now().date()
    return (
        session.scalar(
            select(func.count())
            .select_from(DutySession)
            .where(
                DutySession.session_date == today,
                DutySession.volunteer_id.is_not(None),
                DutySession.admin_confirmed_at.is_(None),
            )
        )
        or 0
    )
