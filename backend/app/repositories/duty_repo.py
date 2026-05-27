"""Data access for ``public.duty_sessions``."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.core.library_sessions import library_now
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
    session.flush()
    return row


def is_volunteer_on_duty_now(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> bool:
    """True when the volunteer has a booked slot covering ``now`` (library timezone)."""
    now = now or library_now()
    today = now.date()
    current_time = now.timetz().replace(tzinfo=None)
    rows = session.scalars(
        select(DutySession).where(
            DutySession.session_date == today,
            DutySession.volunteer_id == volunteer_id,
            DutySession.start_time <= current_time,
            DutySession.end_time >= current_time,
        )
    ).all()
    return len(rows) > 0


def get_active_duty_session_for_volunteer(
    session: Session,
    volunteer_id: uuid.UUID,
    *,
    now: datetime | None = None,
) -> DutySession | None:
    now = now or library_now()
    today = now.date()
    current_time = now.timetz().replace(tzinfo=None)
    return session.scalar(
        select(DutySession)
        .options(joinedload(DutySession.volunteer))
        .where(
            DutySession.session_date == today,
            DutySession.volunteer_id == volunteer_id,
            DutySession.start_time <= current_time,
            DutySession.end_time >= current_time,
        )
        .order_by(DutySession.start_time)
        .limit(1)
    )
