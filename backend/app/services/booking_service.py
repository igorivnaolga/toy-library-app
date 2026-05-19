"""Business rules for member toy reservations."""

from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.availability import AVAILABLE, RESERVED, normalize_availability
from app.models.booking import BOOKING_STATUS_PENDING, Booking
from app.models.toy import Toy
from app.repositories.booking_repo import (
    create_booking,
    get_booking_by_id,
    get_booking_for_user,
    get_pending_booking_for_toy,
    list_bookings_for_user,
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


def create_booking_for_user(
    session: Session, user_id: uuid.UUID, toy_id: str
) -> Booking:
    """Reserve an available toy for the member; updates toy status to reserved."""
    purge_expired_cancelled_bookings(session)
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
        booking = create_booking(session, user_id=user_id, toy_id=toy.toy_id)
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
    purge_expired_cancelled_bookings(session)
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

    toy = _get_toy_row(session, booking.toy_id)
    if toy is not None and normalize_availability(toy.status) == RESERVED:
        toy.status = _TOY_STATUS_IN_LIBRARY

    session.flush()
    loaded = get_booking_by_id(session, booking.id)
    return loaded if loaded is not None else booking
