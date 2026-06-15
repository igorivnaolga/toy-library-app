"""Data access for ``public.bookings``."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import case, delete, func, or_, select, text
from sqlalchemy.orm import Session, joinedload

from app.models.booking import (
    BOOKING_STATUS_CANCELLED,
    BOOKING_STATUS_COMPLETED,
    BOOKING_STATUS_PENDING,
    Booking,
)
from app.repositories.profile_repo import get_user_display_map
from app.models.profile import Profile
from app.models.toy import Toy

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
        .options(joinedload(Booking.toy).joinedload(Toy.image))
        .where(Booking.id == booking_id)
    )


def get_booking_for_user(
    session: Session, booking_id: uuid.UUID, user_id: uuid.UUID
) -> Booking | None:
    return session.scalar(
        select(Booking)
        .options(joinedload(Booking.toy).joinedload(Toy.image))
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
        .options(joinedload(Booking.toy).joinedload(Toy.image))
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


def list_pending_bookings_ready_for_checkout(
    session: Session,
    *,
    on_or_before: date,
) -> list[Booking]:
    """Pending bookings whose pickup day has arrived (volunteer desk)."""
    return list(
        session.scalars(
            select(Booking)
            .options(
                joinedload(Booking.toy).joinedload(Toy.image),
                joinedload(Booking.profile),
            )
            .where(
                Booking.status == BOOKING_STATUS_PENDING,
                Booking.pickup_date.is_not(None),
                Booking.pickup_date <= on_or_before,
            )
            .order_by(Booking.pickup_date.asc(), Booking.created_at.asc())
        )
        .unique()
        .all()
    )


def list_pending_bookings_for_user(
    session: Session,
    user_id: uuid.UUID,
) -> list[Booking]:
    """All pending reservations for one member (includes future pickup days)."""
    return list(
        session.scalars(
            select(Booking)
            .options(
                joinedload(Booking.toy).joinedload(Toy.image),
                joinedload(Booking.profile),
            )
            .where(
                Booking.status == BOOKING_STATUS_PENDING,
                Booking.user_id == user_id,
                Booking.pickup_date.is_not(None),
            )
            .order_by(Booking.pickup_date.asc(), Booking.created_at.asc())
        )
        .unique()
        .all()
    )


def get_pending_booking_for_toy(session: Session, toy_id: str) -> Booking | None:
    return session.scalar(
        select(Booking)
        .options(joinedload(Booking.profile))
        .where(
            Booking.toy_id == toy_id,
            Booking.status == BOOKING_STATUS_PENDING,
        )
    )


def get_pending_bookings_for_toys(
    session: Session,
    toy_ids: list[str],
) -> dict[str, Booking]:
    """Batch load pending bookings keyed by toy_id."""
    if not toy_ids:
        return {}
    unique_ids = list(dict.fromkeys(toy_ids))
    rows = session.scalars(
        select(Booking).where(
            Booking.toy_id.in_(unique_ids),
            Booking.status == BOOKING_STATUS_PENDING,
        )
    ).all()
    return {row.toy_id: row for row in rows}


def mark_booking_cancelled(session: Session, booking: Booking) -> Booking:
    booking.status = BOOKING_STATUS_CANCELLED
    booking.cancelled_at = datetime.now(timezone.utc)
    session.flush()
    return booking


def mark_booking_completed(session: Session, booking: Booking) -> Booking:
    booking.status = BOOKING_STATUS_COMPLETED
    session.flush()
    return booking


def list_bookings_for_admin(
    session: Session,
    *,
    pickup_from: date | None = None,
    pickup_to: date | None = None,
    user_id: uuid.UUID | None = None,
    q: str | None = None,
    limit: int = 200,
) -> list[tuple[Booking, str | None]]:
    """All bookings for admin views, optionally filtered; returns (booking, member_email)."""
    status_rank = case(
        (Booking.status == BOOKING_STATUS_PENDING, 0),
        (Booking.status == BOOKING_STATUS_COMPLETED, 1),
        (Booking.status == BOOKING_STATUS_CANCELLED, 2),
        else_=3,
    )
    stmt = (
        select(Booking)
        .options(
            joinedload(Booking.toy).joinedload(Toy.image),
            joinedload(Booking.profile),
        )
        .order_by(
            status_rank.asc(),
            Booking.pickup_date.asc().nulls_last(),
            Booking.created_at.desc(),
        )
    )
    if pickup_from is not None:
        stmt = stmt.where(Booking.pickup_date >= pickup_from)
    if pickup_to is not None:
        stmt = stmt.where(Booking.pickup_date <= pickup_to)
    if user_id is not None:
        stmt = stmt.where(Booking.user_id == user_id)
    if q:
        pattern = f"%{q.strip().lower()}%"
        email_subq = text(
            """
            exists (
              select 1 from auth.users u
              where u.id = bookings.user_id
                and lower(coalesce(u.email::text, '')) like :pattern
            )
            """
        ).bindparams(pattern=pattern)
        stmt = (
            stmt.join(Booking.toy, isouter=True)
            .join(Booking.profile, isouter=True)
            .where(
                or_(
                    func.lower(Toy.name).like(pattern),
                    func.lower(Booking.toy_id).like(pattern),
                    func.lower(Profile.full_name).like(pattern),
                    email_subq,
                )
            )
        )
    stmt = stmt.limit(limit)
    rows = session.scalars(stmt).unique().all()
    display_map = get_user_display_map(session, {booking.user_id for booking in rows})
    out: list[tuple[Booking, str | None]] = []
    for booking in rows:
        info = display_map.get(booking.user_id)
        email = info[1].strip() if info and info[1] else None
        out.append((booking, email or None))
    return out
