"""Payment ledger persistence."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from app.models.payment import (
    MEMBERSHIP_PAYMENT_TYPES,
    PAYMENT_STATUS_CANCELLED,
    PAYMENT_STATUS_GRANTED,
    PAYMENT_STATUS_PAID_CREDIT,
    PAYMENT_STATUS_PENDING,
    PAYMENT_TYPE_TOP_UP,
    PAYMENT_TYPE_VOLUNTEER_CREDIT,
    TOP_UP_PAID_STATUSES,
    Payment,
)


def create_payment(
    session: Session,
    *,
    user_id: uuid.UUID,
    payment_type: str,
    amount_cents: int,
    description: str | None = None,
    booking_id: uuid.UUID | None = None,
    loan_id: uuid.UUID | None = None,
    toy_id: str | None = None,
    duty_session_id: uuid.UUID | None = None,
) -> Payment:
    payment = Payment(
        user_id=user_id,
        payment_type=payment_type,
        amount_cents=amount_cents,
        description=description,
        booking_id=booking_id,
        loan_id=loan_id,
        toy_id=toy_id,
        duty_session_id=duty_session_id,
    )
    session.add(payment)
    session.flush()
    return payment


def create_recorded_payment(
    session: Session,
    *,
    user_id: uuid.UUID,
    payment_type: str,
    amount_cents: int,
    status: str,
    recorded_by: uuid.UUID,
    description: str | None = None,
    booking_id: uuid.UUID | None = None,
    loan_id: uuid.UUID | None = None,
    toy_id: str | None = None,
    duty_session_id: uuid.UUID | None = None,
    paid_at: datetime | None = None,
) -> Payment:
    payment = Payment(
        user_id=user_id,
        payment_type=payment_type,
        amount_cents=amount_cents,
        description=description,
        booking_id=booking_id,
        loan_id=loan_id,
        toy_id=toy_id,
        duty_session_id=duty_session_id,
        status=status,
        recorded_by=recorded_by,
        paid_at=paid_at or datetime.now(timezone.utc),
    )
    session.add(payment)
    session.flush()
    return payment


def get_payment_by_id(session: Session, payment_id: uuid.UUID) -> Payment | None:
    return session.get(Payment, payment_id)


def sum_credit_grant_cents(session: Session, user_id: uuid.UUID) -> int:
    stmt = select(func.coalesce(func.sum(Payment.amount_cents), 0)).where(
        Payment.user_id == user_id,
        or_(
            and_(
                Payment.payment_type == PAYMENT_TYPE_TOP_UP,
                Payment.status.in_(TOP_UP_PAID_STATUSES),
            ),
            and_(
                Payment.payment_type == PAYMENT_TYPE_VOLUNTEER_CREDIT,
                Payment.status == PAYMENT_STATUS_GRANTED,
            ),
        ),
    )
    return int(session.scalar(stmt) or 0)


def get_volunteer_credit_for_duty_session(
    session: Session,
    duty_session_id: uuid.UUID,
) -> Payment | None:
    stmt = select(Payment).where(
        Payment.duty_session_id == duty_session_id,
        Payment.payment_type == PAYMENT_TYPE_VOLUNTEER_CREDIT,
    )
    return session.scalar(stmt)


def sum_credit_applied_cents(session: Session, user_id: uuid.UUID) -> int:
    stmt = select(func.coalesce(func.sum(Payment.amount_cents), 0)).where(
        Payment.user_id == user_id,
        Payment.status == PAYMENT_STATUS_PAID_CREDIT,
    )
    return int(session.scalar(stmt) or 0)


def list_payments_for_user(
    session: Session,
    user_id: uuid.UUID,
    *,
    limit: int = 100,
) -> list[Payment]:
    stmt = (
        select(Payment)
        .where(Payment.user_id == user_id)
        .order_by(Payment.created_at.desc())
        .limit(limit)
    )
    return list(session.scalars(stmt).all())


def list_pending_payments(
    session: Session,
    user_id: uuid.UUID,
) -> list[Payment]:
    stmt = (
        select(Payment)
        .where(
            Payment.user_id == user_id,
            Payment.status == PAYMENT_STATUS_PENDING,
        )
        .order_by(Payment.created_at.asc())
    )
    return list(session.scalars(stmt).all())


def list_pending_membership_payments(
    session: Session,
    user_id: uuid.UUID,
) -> list[Payment]:
    stmt = (
        select(Payment)
        .where(
            Payment.user_id == user_id,
            Payment.status == PAYMENT_STATUS_PENDING,
            Payment.payment_type.in_(MEMBERSHIP_PAYMENT_TYPES),
        )
        .order_by(Payment.created_at.asc())
    )
    return list(session.scalars(stmt).all())


def cancel_pending_membership_payments(session: Session, user_id: uuid.UUID) -> int:
    rows = list_pending_membership_payments(session, user_id)
    for row in rows:
        row.status = PAYMENT_STATUS_CANCELLED
    session.flush()
    return len(rows)


def mark_payment_status(
    session: Session,
    payment: Payment,
    *,
    status: str,
    recorded_by: uuid.UUID,
    paid_at: datetime | None = None,
) -> Payment:
    payment.status = status
    payment.recorded_by = recorded_by
    payment.paid_at = paid_at or datetime.now(timezone.utc)
    session.flush()
    return payment
