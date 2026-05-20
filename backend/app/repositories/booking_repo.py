"""Data access for ``public.bookings``."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import case, delete, select
from sqlalchemy.orm import Session, joinedload

from app.models.booking import (
    BOOKING_STATUS_CANCELLED,
    BOOKING_STATUS_COMPLETED,
    BOOKING_STATUS_PENDING,
    Booking,
)

# Cancelled rows stay visible briefly, then are removed by ``purge_expired_cancelled_bookings``.
CANCELLED_BOOKING_RETENTION = timedelta(minutes=10)


def purge_expired_cancelled_bookings(session: Session) -> None:
    """Delete cancelled bookings older than ``CANCELLED_BOOKING_RETENTION``."""
    cutoff = datetime.now(timezone.utc) - CANCELLED_BOOKING_RETENTION
    session.execute(
        delete(Booking).where(
            Booking.status == BOOKING_STATUS_CANCELLED,
            Booking.cancelled_at.is_not(None),
            Booking.cancelled_at < cutoff,
        )
    )
    session.flush()


def create_booking(
    session: Session,
    *,
    user_id: uuid.UUID,
    toy_id: str,
    pickup_date: date,
) -> Booking:
    booking = Booking(
        user_id=user_id,
        toy_id=toy_id,
        pickup_date=pickup_date,
        status=BOOKING_STATUS_PENDING,
    )
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
    status_rank = case(
        (Booking.status == BOOKING_STATUS_PENDING, 0),
        (Booking.status == BOOKING_STATUS_COMPLETED, 1),
        (Booking.status == BOOKING_STATUS_CANCELLED, 2),
        else_=3,
    )
    pickup_rank = case(
        (Booking.status == BOOKING_STATUS_PENDING, Booking.pickup_date),
        else_=None,
    )
    stmt = (
        select(Booking)
        .options(joinedload(Booking.toy))
        .where(Booking.user_id == user_id)
        .order_by(
            status_rank.asc(),
            pickup_rank.asc().nulls_last(),
            Booking.created_at.desc(),
        )
    )
    if status is not None:
        stmt = stmt.where(Booking.status == status)
    return list(session.scalars(stmt).unique().all())


def list_pending_bookings_with_pickup(session: Session) -> list[Booking]:
    """Pending bookings that have a pickup date (for missed-pickup cleanup)."""
    return list(
        session.scalars(
            select(Booking).where(
                Booking.status == BOOKING_STATUS_PENDING,
                Booking.pickup_date.is_not(None),
            )
        ).all()
    )


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
