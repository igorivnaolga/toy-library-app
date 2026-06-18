"""Business rules for toy loans: check-out, check-in, renewals."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.availability import AVAILABLE, RESERVED, UNAVAILABLE, normalize_availability
from app.core.library_sessions import (
    LIBRARY_TIMEZONE,
    first_session_on_or_after,
    library_now,
    loan_return_deadline,
    loan_return_session_date,
)
from app.models.booking import BOOKING_STATUS_PENDING
from app.models.category import Category
from app.models.loan import DEFAULT_LOAN_DAYS, LOAN_STATUS_ACTIVE, Loan
from app.models.toy import Toy
from app.repositories.booking_repo import (
    get_booking_by_id,
    get_pending_booking_for_toy,
    get_pending_bookings_for_toys,
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
from app.repositories.toy_repo import get_toy_by_id, resolve_toy_orm
from app.models.payment import PAYMENT_STATUS_PENDING
from app.services.payment_service import (
    PaymentError,
    apply_existing_credit_to_pending_charges,
    apply_rental_payment_action,
    create_rental_payment_for_loan,
)

_TOY_STATUS_IN_LIBRARY = "In library"
_TOY_STATUS_ON_LOAN = "On loan"
_TOY_STATUS_RESERVED = "Reserved"


class LoanError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


def _get_toy_row(session: Session, toy_id: str) -> Toy | None:
    return resolve_toy_orm(session, toy_id)


def _due_date_from_checkout(checkout_day: date) -> date:
    """Due on the first library session on or after checkout + loan period."""
    anchor = checkout_day + timedelta(days=DEFAULT_LOAN_DAYS)
    return first_session_on_or_after(anchor)


def _resolve_check_time(
    *,
    now: datetime | None = None,
    today: date | None = None,
) -> datetime:
    if now is not None:
        return now
    if today is not None:
        # Date-only checks assume midday (before typical session end).
        return datetime.combine(today, time(12, 0), tzinfo=LIBRARY_TIMEZONE)
    return library_now()


def _is_overdue(
    loan: Loan,
    *,
    now: datetime | None = None,
    today: date | None = None,
) -> bool:
    if loan.status != LOAN_STATUS_ACTIVE:
        return False
    check = _resolve_check_time(now=now, today=today)
    return check >= loan_return_deadline(loan.due_date)


def loan_is_due_today(
    loan: Loan,
    *,
    now: datetime | None = None,
    today: date | None = None,
) -> bool:
    """True on the due date while the return session is still open."""
    if loan.status != LOAN_STATUS_ACTIVE:
        return False
    check = _resolve_check_time(now=now, today=today)
    return_session = loan_return_session_date(loan.due_date)
    if check.date() != return_session:
        return False
    return not _is_overdue(loan, now=check)


def renewals_remaining_for_loan(
    session: Session,
    loan: Loan,
    max_renewals: int | None,
) -> int | None:
    """Category renewals left, or zero when another member booked this toy."""
    if max_renewals is None:
        return None
    remaining = max(0, max_renewals - loan.renewal_count)
    pending = get_pending_booking_for_toy(session, loan.toy_id)
    if pending is not None and pending.user_id != loan.user_id:
        return 0
    return remaining


def renewal_context_for_loans(
    session: Session,
    loans: list[Loan],
) -> dict[uuid.UUID, tuple[int | None, int | None]]:
    """Batch max_renewals and renewals_remaining keyed by loan id."""
    if not loans:
        return {}
    pending_by_toy = get_pending_bookings_for_toys(
        session,
        [loan.toy_id for loan in loans],
    )
    category_ids = {
        loan.toy.category_id
        for loan in loans
        if loan.toy is not None and loan.toy.category_id is not None
    }
    max_by_category: dict[uuid.UUID, int | None] = {}
    if category_ids:
        for category in session.scalars(
            select(Category).where(Category.id.in_(category_ids))
        ).all():
            max_by_category[category.id] = category.max_renewals

    context: dict[uuid.UUID, tuple[int | None, int | None]] = {}
    for loan in loans:
        max_renewals: int | None = None
        toy = loan.toy
        if toy is not None and toy.category_id is not None:
            max_renewals = max_by_category.get(toy.category_id)

        renewals_remaining: int | None = None
        if max_renewals is not None:
            renewals_remaining = max(0, max_renewals - loan.renewal_count)
            pending = pending_by_toy.get(loan.toy_id)
            if pending is not None and pending.user_id != loan.user_id:
                renewals_remaining = 0

        context[loan.id] = (max_renewals, renewals_remaining)
    return context


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


def _ensure_toy_available_for_walk_in(
    session: Session,
    toy: Toy,
    *,
    user_id: uuid.UUID,
) -> None:
    """Desk walk-in: block real holds; ignore stale On loan / Reserved labels."""
    pending = get_pending_booking_for_toy(session, toy.toy_id)
    if pending is not None:
        if pending.user_id == user_id:
            raise LoanError(
                "booking_not_checkoutable",
                "This member already has a reservation — check it out from their reservations list.",
            )
        raise LoanError(
            "toy_booked_by_other",
            "This toy is reserved for another member.",
        )

    code = normalize_availability(toy.status)
    if code == UNAVAILABLE:
        raise LoanError(
            "toy_not_available",
            "This toy is marked unavailable (repair, missing, etc.).",
        )


def _ensure_toy_ready_for_booking_checkout(toy: Toy) -> None:
    """Pending booking checkout: toy must be in library (available or reserved)."""
    code = normalize_availability(toy.status)
    if code in {AVAILABLE, RESERVED}:
        return
    raise LoanError(
        "toy_not_available",
        "This toy is not available for check-out right now.",
    )


def check_out_from_booking(
    session: Session,
    booking_id: uuid.UUID,
    *,
    rental_payment: str = "pending",
    payment_method: str | None = None,
    recorded_by: uuid.UUID | None = None,
    allow_early_pickup: bool = False,
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

    if booking.pickup_date is not None and not allow_early_pickup:
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

    _ensure_toy_ready_for_booking_checkout(toy)

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
    payment = create_rental_payment_for_loan(session, loan, toy)
    _apply_checkout_payment(
        session,
        payment,
        rental_payment=rental_payment,
        payment_method=payment_method,
        recorded_by=recorded_by,
    )
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def check_out_walk_in(
    session: Session,
    *,
    user_id: uuid.UUID,
    toy_id: str,
    rental_payment: str = "pending",
    payment_method: str | None = None,
    recorded_by: uuid.UUID | None = None,
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

    _ensure_toy_available_for_walk_in(session, toy, user_id=user_id)

    checkout_day = library_now().date()
    loan = create_loan(
        session,
        user_id=user_id,
        toy_id=toy.toy_id,
        due_date=_due_date_from_checkout(checkout_day),
        checked_out_at=library_now(),
    )
    toy.status = _TOY_STATUS_ON_LOAN
    payment = create_rental_payment_for_loan(session, loan, toy)
    _apply_checkout_payment(
        session,
        payment,
        rental_payment=rental_payment,
        payment_method=payment_method,
        recorded_by=recorded_by,
    )
    session.flush()

    loaded = get_loan_by_id(session, loan.id)
    return loaded if loaded is not None else loan


def _apply_checkout_payment(
    session: Session,
    payment,
    *,
    rental_payment: str,
    payment_method: str | None,
    recorded_by: uuid.UUID | None,
) -> None:
    if payment is None:
        return
    if recorded_by is not None:
        apply_existing_credit_to_pending_charges(
            session,
            payment.user_id,
            recorded_by=recorded_by,
        )
        session.refresh(payment)
        if payment.status != PAYMENT_STATUS_PENDING:
            return
    if rental_payment == "pending":
        return
    if recorded_by is None:
        raise LoanError("recorded_by_required", "Staff id is required to record payment.")
    try:
        apply_rental_payment_action(
            session,
            payment,
            rental_payment=rental_payment,
            payment_method=payment_method,
            recorded_by=recorded_by,
        )
    except PaymentError as exc:
        raise LoanError(exc.code, exc.message) from exc


def check_in_loan(
    session: Session,
    loan_id: uuid.UUID,
    *,
    missing_pieces: int | None = None,
    missing_pieces_detail: str | None = None,
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
    if toy is not None and (
        missing_pieces is not None or missing_pieces_detail is not None
    ):
        if missing_pieces is not None:
            if toy.total_pieces is not None and missing_pieces > toy.total_pieces:
                raise LoanError(
                    "invalid_missing_pieces",
                    "Missing pieces cannot exceed total pieces.",
                )
            toy.missing_pieces = missing_pieces
            if missing_pieces == 0:
                toy.missing_pieces_detail = None
        if missing_pieces_detail is not None:
            cleaned = missing_pieces_detail.strip()
            toy.missing_pieces_detail = cleaned or None
    mark_loan_returned(session, loan)
    if toy is not None:
        if get_pending_booking_for_toy(session, toy.toy_id) is not None:
            toy.status = _TOY_STATUS_RESERVED
        else:
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

    pending = get_pending_booking_for_toy(session, toy.toy_id)
    if pending is not None and pending.user_id != loan.user_id:
        raise LoanError(
            "toy_booked_by_other",
            "Someone has booked this toy after your due date — renewal is not available.",
        )

    new_due = first_session_on_or_after(
        loan.due_date + timedelta(days=DEFAULT_LOAN_DAYS)
    )
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


def loan_is_overdue(
    loan: Loan,
    *,
    now: datetime | None = None,
    today: date | None = None,
) -> bool:
    return _is_overdue(loan, now=now, today=today)
