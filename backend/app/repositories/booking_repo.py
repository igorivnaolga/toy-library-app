"""Data access for ``public.bookings``."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.booking import (
    BOOKING_STATUS_CANCELLED,
    BOOKING_STATUS_PENDING,
    Booking,
)


def create_booking(session: Session, *, user_id: uuid.UUID, toy_id: str) -> Booking:
    booking = Booking(user_id=user_id, toy_id=toy_id, status=BOOKING_STATUS_PENDING)
    session.add(booking)
    session.flush()
    return booking


def get_booking_by_id(session: Session, booking_id: uuid.UUID) -> Booking | None:
    return session.scalar(
        select(Booking)
        .options(joinedload(Booking.toy))
        .where(Booking.id == booking_id)
    )


def get_booking_for_user(
    session: Session, booking_id: uuid.UUID, user_id: uuid.UUID
) -> Booking | None:
    return session.scalar(
        select(Booking)
        .options(joinedload(Booking.toy))
        .where(Booking.id == booking_id, Booking.user_id == user_id)
    )


def list_bookings_for_user(
    session: Session,
    user_id: uuid.UUID,
    *,
    status: str | None = None,
) -> list[Booking]:
    stmt = (
        select(Booking)
        .options(joinedload(Booking.toy))
        .where(Booking.user_id == user_id)
        .order_by(Booking.created_at.desc())
    )
    if status is not None:
        stmt = stmt.where(Booking.status == status)
    return list(session.scalars(stmt).unique().all())


def get_pending_booking_for_toy(session: Session, toy_id: str) -> Booking | None:
    return session.scalar(
        select(Booking).where(
            Booking.toy_id == toy_id,
            Booking.status == BOOKING_STATUS_PENDING,
        )
    )


def mark_booking_cancelled(session: Session, booking: Booking) -> Booking:
    booking.status = BOOKING_STATUS_CANCELLED
    booking.cancelled_at = datetime.now(timezone.utc)
    session.flush()
    return booking
