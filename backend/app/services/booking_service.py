"""Business rules for member toy reservations."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.availability import (
    AVAILABLE,
    ON_LOAN,
    RESERVED,
    member_availability,
    normalize_availability,
)
from app.core.reservation_hold import reservation_hold_opens_on
from app.core.library_sessions import (
    LIBRARY_TIMEZONE,
    allowed_pickup_dates,
    bookable_horizon_end,
    earliest_bookable_date,
    first_session_after_loan_due,
    first_session_after_reservation_hold,
    first_session_on_or_after,
    format_pickup_label,
    is_library_session_day,
    latest_bookable_date,
    library_now,
    session_end_datetime,
    session_pickup_dates_between,
)
from app.repositories.loan_repo import get_active_loan_for_toy
from app.models.booking import BOOKING_STATUS_PENDING, Booking
from app.models.loan import DEFAULT_LOAN_DAYS
from app.models.toy import Toy
from app.repositories.booking_repo import (
    create_booking,
    get_booking_by_id,
    get_booking_for_user,
    get_pending_booking_for_toy,
    list_bookings_for_admin,
    list_bookings_for_user,
    list_pending_bookings_for_user,
    list_pending_bookings_ready_for_checkout,
    list_pending_bookings_with_pickup,
    mark_booking_cancelled,
    purge_expired_cancelled_bookings,
)
from app.repositories.toy_repo import _db_toy_count, get_toy_by_id, resolve_toy_orm

# Match seed CSV labels; ``normalize_availability`` maps these to available/reserved.
_TOY_STATUS_IN_LIBRARY = "In library"
_TOY_STATUS_ON_LOAN = "On loan"
_TOY_STATUS_RESERVED = "Reserved"


class BookingError(Exception):
    """Raised when a booking action violates domain rules."""

    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def _get_toy_row(session: Session, toy_id: str) -> Toy | None:
    return resolve_toy_orm(session, toy_id)


def _release_toy_if_reserved(session: Session, toy_id: str) -> None:
    toy = _get_toy_row(session, toy_id)
    if toy is None:
        return
    if normalize_availability(toy.status) != RESERVED:
        return
    if get_active_loan_for_toy(session, toy_id) is not None:
        toy.status = _TOY_STATUS_ON_LOAN
    else:
        toy.status = _TOY_STATUS_IN_LIBRARY


def _earliest_pickup_after_active_loan(session: Session, toy: Toy) -> date | None:
    """First session after loan due date when the toy still has an active loan."""
    loan = get_active_loan_for_toy(session, toy.toy_id)
    if loan is None:
        return None
    return first_session_after_loan_due(loan.due_date)


def _reservation_day_for_toy(session: Session, toy: Toy) -> date | None:
    pending = get_pending_booking_for_toy(session, toy.toy_id)
    if pending is None:
        return None
    created_at = getattr(pending, "created_at", None)
    if not isinstance(created_at, datetime):
        return None
    return created_at.astimezone(LIBRARY_TIMEZONE).date()


def _earliest_pickup_after_reservation(session: Session, toy: Toy) -> date | None:
    """First session after the two-week hold from when the toy was reserved."""
    reservation_day = _reservation_day_for_toy(session, toy)
    if reservation_day is None:
        return None
    return first_session_after_reservation_hold(
        reservation_day,
        hold_days=DEFAULT_LOAN_DAYS,
    )


def _earliest_pickup_for_toy(
    session: Session,
    toy: Toy,
    *,
    superseded_hold_end: date | None = None,
) -> date | None:
    """Earliest allowed pickup from loan-end and/or reservation-hold rules."""
    candidates: list[date] = []

    if superseded_hold_end is not None:
        candidates.append(superseded_hold_end)

    availability = normalize_availability(toy.status)
    if availability in {ON_LOAN, RESERVED}:
        loan_earliest = _earliest_pickup_after_active_loan(session, toy)
        if loan_earliest is not None:
            candidates.append(loan_earliest)

    if availability == RESERVED or (
        availability == ON_LOAN
        and get_pending_booking_for_toy(session, toy.toy_id) is not None
    ):
        reservation_earliest = _earliest_pickup_after_reservation(session, toy)
        if reservation_earliest is not None:
            candidates.append(reservation_earliest)

    if not candidates:
        return None
    return max(candidates)


def _validate_pickup_for_toy(
    session: Session,
    toy: Toy,
    pickup_date: date,
    *,
    superseded_hold_end: date | None = None,
) -> None:
    """Enforce loan-end and reservation-hold pickup constraints."""
    earliest = _earliest_pickup_for_toy(
        session,
        toy,
        superseded_hold_end=superseded_hold_end,
    )
    if earliest is not None and pickup_date < earliest:
        raise BookingError(
            "pickup_before_loan_due",
            f"Pickup day must be on or after {format_pickup_label(earliest)}.",
        )


def _anchor_pickup_for_pending_booking(session: Session, toy: Toy) -> date | None:
    """Session anchor for a reserved toy's existing pending booking."""
    pending = get_pending_booking_for_toy(session, toy.toy_id)
    if pending is None or pending.pickup_date is None:
        return None
    return first_session_on_or_after(pending.pickup_date)


def _pickup_window_for_toy(
    session: Session,
    toy: Toy | None,
    *,
    now: datetime | None = None,
    superseded_hold_end: date | None = None,
) -> tuple[date, date]:
    """Bookable pickup range; extends 6 months from loan end or reserved pickup when needed."""
    now = now or library_now()
    start = earliest_bookable_date(now=now)
    end = latest_bookable_date(now=now)
    if toy is None:
        return start, end

    earliest = _earliest_pickup_for_toy(
        session,
        toy,
        superseded_hold_end=superseded_hold_end,
    )
    if earliest is not None:
        start = max(start, earliest)
        end = max(end, bookable_horizon_end(earliest))

    if normalize_availability(toy.status) == RESERVED:
        anchor = _anchor_pickup_for_pending_booking(session, toy)
        if anchor is not None:
            end = max(end, bookable_horizon_end(anchor))
    return start, end


def _pickup_dates_for_toy(
    session: Session,
    toy: Toy | None,
    *,
    now: datetime | None = None,
    superseded_hold_end: date | None = None,
) -> list[date]:
    start, end = _pickup_window_for_toy(
        session,
        toy,
        now=now,
        superseded_hold_end=superseded_hold_end,
    )
    return session_pickup_dates_between(start, end)


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


def list_pickup_date_options(
    session: Session | None = None,
    *,
    toy_id: str | None = None,
) -> list[dict[str, str | date]]:
    """Public pickup choices for the booking UI (Wed/Sat within the bookable window)."""
    toy = None
    if session is not None and toy_id:
        toy = _get_toy_row(session, toy_id.strip())
    if session is not None:
        dates = _pickup_dates_for_toy(session, toy)
    else:
        dates = allowed_pickup_dates()

    options: list[dict[str, str | date]] = []
    for day in dates:
        weekday = "wednesday" if day.weekday() == 2 else "saturday"
        options.append(
            {
                "date": day,
                "label": format_pickup_label(day),
                "weekday": weekday,
            }
        )
    return options


def _validate_pickup_date(
    pickup_date: date,
    *,
    session: Session | None = None,
    toy: Toy | None = None,
    superseded_hold_end: date | None = None,
) -> None:
    if not is_library_session_day(pickup_date):
        raise BookingError(
            "invalid_pickup_date",
            "Pickup day must be a library session (Wednesday or Saturday).",
        )
    if session is not None and toy is not None:
        _validate_pickup_for_toy(
            session,
            toy,
            pickup_date,
            superseded_hold_end=superseded_hold_end,
        )
    allowed = (
        _pickup_dates_for_toy(
            session,
            toy,
            superseded_hold_end=superseded_hold_end,
        )
        if session is not None
        else allowed_pickup_dates()
    )
    if pickup_date not in allowed:
        raise BookingError(
            "invalid_pickup_date",
            "Pickup day must be within the booking window on an open library session.",
        )


def create_booking_for_user(
    session: Session,
    user_id: uuid.UUID,
    toy_id: str,
    pickup_date: date,
) -> Booking:
    """Reserve an available toy for the member; updates toy status to reserved."""
    _run_booking_maintenance(session)

    toy = _get_toy_row(session, toy_id)
    if toy is None:
        if _db_toy_count() == 0 and get_toy_by_id(toy_id) is not None:
            raise BookingError(
                "catalog_not_seeded",
                "Toy catalog is not loaded in the database yet. "
                "From backend/, run: python -m app.scripts.seed_from_csv",
            )
        raise BookingError("toy_not_found", "Toy not found.")

    loan = get_active_loan_for_toy(session, toy.toy_id)
    pending = get_pending_booking_for_toy(session, toy.toy_id)
    superseded_hold_end: date | None = None

    if pending is not None:
        if pending.user_id == user_id:
            raise BookingError(
                "toy_already_reserved",
                "You already have a pending booking for this toy.",
            )
        hold_end = reservation_hold_opens_on(pending)
        if hold_end is not None and pickup_date < hold_end:
            raise BookingError(
                "pickup_before_loan_due",
                f"Pickup day must be on or after {format_pickup_label(hold_end)}.",
            )
        superseded_hold_end = hold_end
        mark_booking_cancelled(session, pending)
        _release_toy_if_reserved(session, toy.toy_id)
        pending = None

    availability = member_availability(
        toy.status,
        has_active_loan=loan is not None,
        has_pending_booking=False,
    )
    if availability not in {AVAILABLE, ON_LOAN}:
        raise BookingError(
            "toy_not_available",
            "This toy is not available for booking right now.",
        )

    if availability == ON_LOAN:
        if loan is None:
            raise BookingError(
                "toy_not_available",
                "This toy is not available for booking right now.",
            )
        if loan.user_id == user_id:
            raise BookingError(
                "toy_on_loan_to_you",
                "Return this toy before booking it again.",
            )

    _validate_pickup_date(
        pickup_date,
        session=session,
        toy=toy,
        superseded_hold_end=superseded_hold_end,
    )

    try:
        booking = create_booking(
            session,
            user_id=user_id,
            toy_id=toy.toy_id,
            pickup_date=pickup_date,
        )
        if availability == AVAILABLE:
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


def reschedule_booking_for_user(
    session: Session,
    user_id: uuid.UUID,
    booking_id: uuid.UUID,
    pickup_date: date,
) -> Booking:
    """Change pickup day on a pending booking owned by the member."""
    _run_booking_maintenance(session)

    booking = get_booking_for_user(session, booking_id, user_id)
    if booking is None:
        raise BookingError("booking_not_found", "Booking not found.")

    if booking.status != BOOKING_STATUS_PENDING:
        raise BookingError(
            "booking_not_reschedulable",
            "Only pending bookings can change pickup day.",
        )

    toy = booking.toy or _get_toy_row(session, booking.toy_id)
    _validate_pickup_date(pickup_date, session=session, toy=toy)

    booking.pickup_date = pickup_date
    session.flush()
    loaded = get_booking_by_id(session, booking.id)
    return loaded if loaded is not None else booking


def list_pending_bookings_for_checkout_service(session: Session) -> list[Booking]:
    """Volunteer desk: pending bookings ready for check-out today or earlier."""
    _run_booking_maintenance(session)
    today = library_now().date()
    return list_pending_bookings_ready_for_checkout(session, on_or_before=today)


def list_pending_bookings_for_user_service(
    session: Session,
    user_id: uuid.UUID,
) -> list[Booking]:
    """Volunteer desk: all pending reservations for one member."""
    _run_booking_maintenance(session)
    return list_pending_bookings_for_user(session, user_id)


def list_bookings_for_admin_service(
    session: Session,
    *,
    pickup_from: date | None = None,
    pickup_to: date | None = None,
    user_id: uuid.UUID | None = None,
    q: str | None = None,
    limit: int = 200,
) -> list[tuple[Booking, str | None]]:
    _run_booking_maintenance(session)
    return list_bookings_for_admin(
        session,
        pickup_from=pickup_from,
        pickup_to=pickup_to,
        user_id=user_id,
        q=q,
        limit=limit,
    )
