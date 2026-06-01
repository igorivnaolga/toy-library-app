"""Business rules for toy loans: check-out, check-in, renewals."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.core.availability import AVAILABLE, normalize_availability
from app.core.library_sessions import library_now
from app.models.booking import BOOKING_STATUS_PENDING
from app.models.category import Category
from app.models.loan import DEFAULT_LOAN_DAYS, LOAN_STATUS_ACTIVE, Loan
from app.models.toy import Toy
from app.repositories.booking_repo import (
    get_booking_by_id,
    mark_booking_completed,
)
from app.repositories.loan_repo import (
    create_loan,
    extend_loan_due_date,
    get_active_loan_for_toy,
    get_loan_by_id,
    list_active_loans,
    list_loans_for_user,
    mark_loan_returned,
)
from app.repositories.toy_repo import get_toy_by_id

_TOY_STATUS_IN_LIBRARY = "In library"
_TOY_STATUS_ON_LOAN = "On loan"


class LoanError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def _get_toy_row(session: Session, toy_id: str) -> Toy | None:
    toy_id_norm = toy_id.strip()
    if not toy_id_norm:
        return None
    from sqlalchemy import select

    return session.scalar(select(Toy).where(Toy.toy_id == toy_id_norm))


def _due_date_from_checkout(checkout_day: date) -> date:
    return checkout_day + timedelta(days=DEFAULT_LOAN_DAYS)


def _is_overdue(loan: Loan, today: date | None = None) -> bool:
    if loan.status != LOAN_STATUS_ACTIVE:
        return False
    ref = today or library_now().date()
    return loan.due_date < ref


def _max_renewals_for_toy(session: Session, toy: Toy) -> int:
    if toy.category_id is None:
        return 0
    category = session.get(Category, toy.category_id)
    if category is None or category.max_renewals is None:
        return 0
    return max(0, category.max_renewals)


def _ensure_toy_available_for_checkout(toy: Toy) -> None:
    code = normalize_availability(toy.status)
    if code != AVAILABLE:
        raise LoanError(
            "toy_not_available",
            "This toy is not available for check-out right now.",
        )


def check_out_from_booking(
    session: Session,
    booking_id: uuid.UUID,
) -> Loan:
    """Volunteer check-out: pending booking → active loan."""
    booking = get_booking_by_id(session, booking_id)
    if booking is None:
        raise LoanError("booking_not_found", "Booking not found.")

    if booking.status != BOOKING_STATUS_PENDING:
        raise LoanError(
            "booking_not_checkoutable",
            "Only pending bookings can be checked out.",
        )

    if booking.pickup_date is not None:
        today = library_now().date()
        if booking.pickup_date > today:
            raise LoanError(
                "pickup_not_due",
                "Pickup day has not arrived yet for this booking.",
            )

    toy = booking.toy or _get_toy_row(session, booking.toy_id)
    if toy is None:
        raise LoanError("toy_not_found", "Toy not found.")

    if get_active_loan_for_toy(session, toy.toy_id) is not None:
        raise LoanError("toy_on_loan", "This toy already has an active loan.")

    _ensure_toy_available_for_checkout(toy)

    checkout_day = library_now().date()
    loan = create_loan(
        session,
        user_id=booking.user_id,
        toy_id=toy.toy_id,
        booking_id=booking.id,
        due_date=_due_date_from_checkout(checkout_day),
        checked_out_at=library_now(),
    )
    mark_booking_completed(session, booking)
    toy.status = _TOY_STATUS_ON_LOAN
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def check_out_walk_in(
    session: Session,
    *,
    user_id: uuid.UUID,
    toy_id: str,
) -> Loan:
    """Volunteer check-out without a prior booking."""
    toy = _get_toy_row(session, toy_id)
    if toy is None:
        if get_toy_by_id(toy_id) is not None:
            raise LoanError(
                "catalog_not_seeded",
                "Toy catalog is not loaded in the database yet.",
            )
        raise LoanError("toy_not_found", "Toy not found.")

    if get_active_loan_for_toy(session, toy.toy_id) is not None:
        raise LoanError("toy_on_loan", "This toy already has an active loan.")

    _ensure_toy_available_for_checkout(toy)

    checkout_day = library_now().date()
    loan = create_loan(
        session,
        user_id=user_id,
        toy_id=toy.toy_id,
        due_date=_due_date_from_checkout(checkout_day),
        checked_out_at=library_now(),
    )
    toy.status = _TOY_STATUS_ON_LOAN
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def check_in_loan(
    session: Session,
    loan_id: uuid.UUID,
    *,
    missing_pieces: int | None = None,
) -> Loan:
    """Volunteer check-in: return toy and close the loan."""
    loan = get_loan_by_id(session, loan_id)
    if loan is None:
        raise LoanError("loan_not_found", "Loan not found.")

    if loan.status != LOAN_STATUS_ACTIVE:
        raise LoanError(
            "loan_not_active",
            "Only active loans can be checked in.",
        )

    toy = loan.toy or _get_toy_row(session, loan.toy_id)
    if missing_pieces is not None and toy is not None:
        if toy.total_pieces is not None and missing_pieces > toy.total_pieces:
            raise LoanError(
                "invalid_missing_pieces",
                "Missing pieces cannot exceed total pieces.",
            )
        toy.missing_pieces = missing_pieces
    mark_loan_returned(session, loan)
    if toy is not None:
        toy.status = _TOY_STATUS_IN_LIBRARY
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def renew_loan_for_user(
    session: Session,
    user_id: uuid.UUID,
    loan_id: uuid.UUID,
) -> Loan:
    """Member renews an active loan if category allows."""
    loan = get_loan_by_id(session, loan_id)
    if loan is None:
        raise LoanError("loan_not_found", "Loan not found.")

    if loan.user_id != user_id:
        raise LoanError("loan_not_found", "Loan not found.")

    if loan.status != LOAN_STATUS_ACTIVE:
        raise LoanError(
            "loan_not_renewable",
            "Only active loans can be renewed.",
        )

    toy = loan.toy or _get_toy_row(session, loan.toy_id)
    if toy is None:
        raise LoanError("toy_not_found", "Toy not found.")

    max_renewals = _max_renewals_for_toy(session, toy)
    if loan.renewal_count >= max_renewals:
        raise LoanError(
            "renewals_exhausted",
            f"This toy category allows at most {max_renewals} renewal(s).",
        )

    new_due = loan.due_date + timedelta(days=DEFAULT_LOAN_DAYS)
    extend_loan_due_date(session, loan, new_due)
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def list_my_loans_service(
    session: Session,
    user_id: uuid.UUID,
    *,
    active_only: bool = False,
) -> list[Loan]:
    return list_loans_for_user(session, user_id, active_only=active_only)


def list_active_loans_service(session: Session) -> list[Loan]:
    return list_active_loans(session)


def loan_is_overdue(loan: Loan, *, today: date | None = None) -> bool:
    return _is_overdue(loan, today)
