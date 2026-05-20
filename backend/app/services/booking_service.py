"""Business rules for member toy reservations."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.availability import AVAILABLE, RESERVED, normalize_availability
from app.core.library_sessions import (
    allowed_pickup_dates,
    format_pickup_label,
    is_allowed_pickup_date,
    is_library_session_day,
    library_now,
    session_end_datetime,
)
from app.models.booking import BOOKING_STATUS_PENDING, Booking
from app.models.toy import Toy
from app.repositories.booking_repo import (
    create_booking,
    get_booking_by_id,
    get_booking_for_user,
    get_pending_booking_for_toy,
    list_bookings_for_user,
    list_pending_bookings_with_pickup,
    mark_booking_cancelled,
    purge_expired_cancelled_bookings,
)
from app.repositories.toy_repo import _db_toy_count, get_toy_by_id

# Match seed CSV labels; ``normalize_availability`` maps these to available/reserved.
_TOY_STATUS_IN_LIBRARY = "In library"
_TOY_STATUS_RESERVED = "Reserved"


class BookingError(Exception):
    """Raised when a booking action violates domain rules."""

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def _get_toy_row(session: Session, toy_id: str) -> Toy | None:
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    return session.scalar(select(Toy).where(Toy.toy_id == toy_id_norm))


def _release_toy_if_reserved(session: Session, toy_id: str) -> None:
    toy = _get_toy_row(session, toy_id)
    if toy is not None and normalize_availability(toy.status) == RESERVED:
        toy.status = _TOY_STATUS_IN_LIBRARY


def _run_booking_maintenance(session: Session) -> None:
    purge_expired_cancelled_bookings(session)
    expire_missed_pickup_bookings(session)


def expire_missed_pickup_bookings(session: Session) -> None:
    """Auto-cancel pending bookings whose Wed/Sat pickup session has ended."""
    now = library_now()
    for booking in list_pending_bookings_with_pickup(session):
        if booking.pickup_date is None:
            continue
        if session_end_datetime(booking.pickup_date) >= now:
            continue
        mark_booking_cancelled(session, booking)
        _release_toy_if_reserved(session, booking.toy_id)
    session.flush()


def list_pickup_date_options() -> list[dict[str, str | date]]:
    """Public pickup choices for the booking UI (next 4 weeks of Wed/Sat)."""
    options: list[dict[str, str | date]] = []
    for day in allowed_pickup_dates():
        weekday = "wednesday" if day.weekday() == 2 else "saturday"
        options.append(
            {
                "date": day,
                "label": format_pickup_label(day),
                "weekday": weekday,
            }
        )
    return options


def create_booking_for_user(
    session: Session,
    user_id: uuid.UUID,
    toy_id: str,
    pickup_date: date,
) -> Booking:
    """Reserve an available toy for the member; updates toy status to reserved."""
    _run_booking_maintenance(session)

    if not is_library_session_day(pickup_date):
        raise BookingError(
            "invalid_pickup_date",
            "Pickup day must be a library session (Wednesday or Saturday).",
        )
    if not is_allowed_pickup_date(pickup_date):
        raise BookingError(
            "invalid_pickup_date",
            "Pickup day must be within the next 4 weeks on an open library session.",
        )

    toy = _get_toy_row(session, toy_id)
    if toy is None:
        if _db_toy_count() == 0 and get_toy_by_id(toy_id) is not None:
            raise BookingError(
                "catalog_not_seeded",
                "Toy catalog is not loaded in the database yet. "
                "From backend/, run: python -m app.scripts.seed_from_csv",
            )
        raise BookingError("toy_not_found", "Toy not found.")

    if normalize_availability(toy.status) != AVAILABLE:
        raise BookingError(
            "toy_not_available",
            "This toy is not available for booking right now.",
        )

    if get_pending_booking_for_toy(session, toy.toy_id) is not None:
        raise BookingError(
            "toy_already_reserved",
            "This toy already has a pending booking.",
        )

    try:
        booking = create_booking(
            session,
            user_id=user_id,
            toy_id=toy.toy_id,
            pickup_date=pickup_date,
        )
        toy.status = _TOY_STATUS_RESERVED
        session.flush()
    except IntegrityError as e:
        session.rollback()
        raise BookingError(
            "toy_already_reserved",
            "This toy already has a pending booking.",
        ) from e

    loaded = get_booking_by_id(session, booking.id)
    return loaded if loaded is not None else booking


def list_bookings_for_user_service(
    session: Session, user_id: uuid.UUID
) -> list[Booking]:
    _run_booking_maintenance(session)
    return list_bookings_for_user(session, user_id)


def cancel_booking_for_user(
    session: Session, user_id: uuid.UUID, booking_id: uuid.UUID
) -> Booking:
    """Cancel a pending booking owned by the user; restore toy availability when reserved."""
    booking = get_booking_for_user(session, booking_id, user_id)
    if booking is None:
        raise BookingError("booking_not_found", "Booking not found.")

    if booking.status != BOOKING_STATUS_PENDING:
        raise BookingError(
            "booking_not_cancellable",
            "Only pending bookings can be cancelled.",
        )

    mark_booking_cancelled(session, booking)
    _release_toy_if_reserved(session, booking.toy_id)

    session.flush()
    loaded = get_booking_by_id(session, booking.id)
    return loaded if loaded is not None else booking
