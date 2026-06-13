"""Payment ledger business rules (Phase 1: staff-recorded payments)."""

from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy.orm import Session

from app.core.membership_fees import charges_for_tier
from app.core.volunteer_credit import (
    VOLUNTEER_DUTY_CREDIT_CENTS,
    volunteer_duty_credit_description,
)
from app.models.loan import Loan
from app.models.duty_session import DutySession
from app.models.payment import (
    MEMBERSHIP_PAYMENT_TYPES,
    PAID_STATUSES,
    PAYMENT_STATUS_PAID_BANK,
    PAYMENT_STATUS_PAID_CASH,
    PAYMENT_STATUS_PAID_CREDIT,
    PAYMENT_STATUS_PAID_EFTPOS,
    PAYMENT_STATUS_GRANTED,
    PAYMENT_STATUS_PENDING,
    PAYMENT_TYPE_RENTAL,
    PAYMENT_TYPE_TOP_UP,
    PAYMENT_TYPE_VOLUNTEER_CREDIT,
    Payment,
)
from app.models.toy import Toy
from app.repositories.payment_repo import (
    cancel_pending_membership_payments,
    create_payment,
    create_recorded_payment,
    get_payment_by_id,
    get_volunteer_credit_for_duty_session,
    list_pending_membership_payments,
    list_pending_payments,
    list_payments_for_user,
    mark_payment_status,
    sum_credit_applied_cents,
    sum_credit_grant_cents,
)

_METHOD_TO_STATUS = {
    "cash": PAYMENT_STATUS_PAID_CASH,
    "eftpos": PAYMENT_STATUS_PAID_EFTPOS,
    "bank": PAYMENT_STATUS_PAID_BANK,
}


class PaymentError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


@dataclass(frozen=True)
class MembershipPaymentSummary:
    due_cents: int
    fees_paid: bool
    pending_count: int


@dataclass(frozen=True)
class BalanceSummary:
    balance_due_cents: int
    membership_due_cents: int
    rental_due_cents: int
    credit_balance_cents: int


def credit_balance_cents(session: Session, user_id: uuid.UUID) -> int:
    """Unapplied account credit from top-ups and volunteer duty shifts."""
    granted = sum_credit_grant_cents(session, user_id)
    applied = sum_credit_applied_cents(session, user_id)
    return max(0, granted - applied)


def balance_summary(session: Session, user_id: uuid.UUID) -> BalanceSummary:
    pending = list_pending_payments(session, user_id)
    membership_due = sum(
        p.amount_cents
        for p in pending
        if p.payment_type in MEMBERSHIP_PAYMENT_TYPES
    )
    rental_due = sum(
        p.amount_cents for p in pending if p.payment_type == PAYMENT_TYPE_RENTAL
    )
    charges_due = membership_due + rental_due
    credit = credit_balance_cents(session, user_id)
    return BalanceSummary(
        balance_due_cents=max(0, charges_due - credit),
        membership_due_cents=membership_due,
        rental_due_cents=rental_due,
        credit_balance_cents=credit,
    )


def create_membership_payments_for_tier(
    session: Session,
    user_id: uuid.UUID,
    tier: str,
) -> list[Payment]:
    """Create pending membership (and casual bond) charges for a tier."""
    payments: list[Payment] = []
    for payment_type, amount_cents, description in charges_for_tier(tier):
        payments.append(
            create_payment(
                session,
                user_id=user_id,
                payment_type=payment_type,
                amount_cents=amount_cents,
                description=description,
            )
        )
    return payments


def refresh_membership_payments_for_tier(
    session: Session,
    user_id: uuid.UUID,
    tier: str,
) -> list[Payment]:
    """Replace pending membership charges when tier changes."""
    cancel_pending_membership_payments(session, user_id)
    return create_membership_payments_for_tier(session, user_id, tier)


def membership_payment_summary(
    session: Session,
    user_id: uuid.UUID,
) -> MembershipPaymentSummary:
    pending = list_pending_membership_payments(session, user_id)
    due = sum(p.amount_cents for p in pending)
    return MembershipPaymentSummary(
        due_cents=due,
        fees_paid=len(pending) == 0,
        pending_count=len(pending),
    )


def assert_membership_paid_for_booking(session: Session, user_id: uuid.UUID) -> None:
    summary = membership_payment_summary(session, user_id)
    if not summary.fees_paid:
        raise PaymentError(
            "membership_unpaid",
            "Pay your membership fees at the library before booking toys.",
        )


def create_rental_payment_for_loan(
    session: Session,
    loan: Loan,
    toy: Toy | None,
) -> Payment | None:
    if toy is None or toy.rental_price_cents is None or toy.rental_price_cents <= 0:
        return None
    toy_label = toy.name or toy.toy_id
    return create_payment(
        session,
        user_id=loan.user_id,
        payment_type=PAYMENT_TYPE_RENTAL,
        amount_cents=toy.rental_price_cents,
        description=f"Toy rental — {toy_label}",
        booking_id=loan.booking_id,
        loan_id=loan.id,
        toy_id=toy.toy_id,
    )


def apply_rental_payment_action(
    session: Session,
    payment: Payment | None,
    *,
    rental_payment: str,
    payment_method: str | None,
    recorded_by: uuid.UUID,
) -> Payment | None:
    """Leave rental charge pending or mark paid at checkout."""
    if payment is None:
        return None
    if rental_payment == "pending":
        return payment
    if rental_payment != "paid":
        raise PaymentError("invalid_rental_payment", "rental_payment must be pending or paid.")
    if not payment_method:
        raise PaymentError(
            "payment_method_required",
            "Select cash, eftpos, or bank when marking rental as paid.",
        )
    return mark_payment_paid(
        session,
        payment.id,
        method=payment_method,
        recorded_by=recorded_by,
    )


def mark_payment_paid(
    session: Session,
    payment_id: uuid.UUID,
    *,
    method: str,
    recorded_by: uuid.UUID,
) -> Payment:
    payment = get_payment_by_id(session, payment_id)
    if payment is None:
        raise PaymentError("payment_not_found", "Payment not found.")
    if payment.status != PAYMENT_STATUS_PENDING:
        raise PaymentError(
            "payment_not_pending",
            "Only pending payments can be marked as paid.",
        )
    status = _METHOD_TO_STATUS.get(method)
    if status is None:
        raise PaymentError("invalid_method", "Payment method must be cash, eftpos, or bank.")
    return mark_payment_status(
        session,
        payment,
        status=status,
        recorded_by=recorded_by,
    )


def mark_all_membership_payments_paid(
    session: Session,
    user_id: uuid.UUID,
    *,
    method: str,
    recorded_by: uuid.UUID,
) -> list[Payment]:
    pending = list_pending_membership_payments(session, user_id)
    if not pending:
        raise PaymentError(
            "no_pending_membership",
            "This member has no pending membership payments.",
        )
    status = _METHOD_TO_STATUS.get(method)
    if status is None:
        raise PaymentError("invalid_method", "Payment method must be cash, eftpos, or bank.")
    updated: list[Payment] = []
    for payment in pending:
        updated.append(
            mark_payment_status(
                session,
                payment,
                status=status,
                recorded_by=recorded_by,
            )
        )
    return updated


def _apply_account_credit_to_pending(
    session: Session,
    user_id: uuid.UUID,
    amount_cents: int,
    recorded_by: uuid.UUID,
) -> None:
    credit_remaining = amount_cents
    for payment in list_pending_payments(session, user_id):
        if credit_remaining < payment.amount_cents:
            continue
        mark_payment_status(
            session,
            payment,
            status=PAYMENT_STATUS_PAID_CREDIT,
            recorded_by=recorded_by,
        )
        credit_remaining -= payment.amount_cents


def apply_existing_credit_to_pending_charges(
    session: Session,
    user_id: uuid.UUID,
    *,
    recorded_by: uuid.UUID,
) -> int:
    """Apply unapplied account credit to pending charges (oldest first)."""
    credit_remaining = credit_balance_cents(session, user_id)
    if credit_remaining <= 0:
        return 0
    applied = 0
    for payment in list_pending_payments(session, user_id):
        if credit_remaining < payment.amount_cents:
            continue
        mark_payment_status(
            session,
            payment,
            status=PAYMENT_STATUS_PAID_CREDIT,
            recorded_by=recorded_by,
        )
        credit_remaining -= payment.amount_cents
        applied += payment.amount_cents
    return applied


def record_top_up(
    session: Session,
    user_id: uuid.UUID,
    *,
    amount_cents: int,
    method: str,
    recorded_by: uuid.UUID,
) -> Payment:
    """Record a member top-up and apply credit to pending charges (oldest first)."""
    if amount_cents <= 0:
        raise PaymentError("invalid_amount", "Top-up amount must be greater than zero.")
    status = _METHOD_TO_STATUS.get(method)
    if status is None:
        raise PaymentError("invalid_method", "Payment method must be cash, eftpos, or bank.")

    top_up = create_recorded_payment(
        session,
        user_id=user_id,
        payment_type=PAYMENT_TYPE_TOP_UP,
        amount_cents=amount_cents,
        description="Account top-up",
        status=status,
        recorded_by=recorded_by,
    )

    _apply_account_credit_to_pending(
        session,
        user_id,
        amount_cents,
        recorded_by,
    )

    return top_up


def grant_volunteer_duty_credit(
    session: Session,
    duty_session: DutySession,
    *,
    recorded_by: uuid.UUID,
) -> Payment | None:
    """Award hire credit when admin confirms a volunteer duty shift."""
    if duty_session.volunteer_id is None:
        return None
    existing = get_volunteer_credit_for_duty_session(session, duty_session.id)
    if existing is not None:
        return existing

    credit = create_recorded_payment(
        session,
        user_id=duty_session.volunteer_id,
        payment_type=PAYMENT_TYPE_VOLUNTEER_CREDIT,
        amount_cents=VOLUNTEER_DUTY_CREDIT_CENTS,
        description=volunteer_duty_credit_description(duty_session.session_date),
        status=PAYMENT_STATUS_GRANTED,
        recorded_by=recorded_by,
        duty_session_id=duty_session.id,
    )
    _apply_account_credit_to_pending(
        session,
        duty_session.volunteer_id,
        VOLUNTEER_DUTY_CREDIT_CENTS,
        recorded_by,
    )
    return credit


def list_user_payments_service(
    session: Session,
    user_id: uuid.UUID,
) -> list[Payment]:
    return list_payments_for_user(session, user_id)


def is_paid_status(status: str) -> bool:
    return status in PAID_STATUSES
