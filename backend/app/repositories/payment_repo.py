"""Payment ledger persistence."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.payment import (
    MEMBERSHIP_PAYMENT_TYPES,
    PAYMENT_STATUS_CANCELLED,
    PAYMENT_STATUS_PENDING,
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
) -> Payment:
    payment = Payment(
        user_id=user_id,
        payment_type=payment_type,
        amount_cents=amount_cents,
        description=description,
        booking_id=booking_id,
        loan_id=loan_id,
        toy_id=toy_id,
    )
    session.add(payment)
    session.flush()
    return payment


def get_payment_by_id(session: Session, payment_id: uuid.UUID) -> Payment | None:
    return session.get(Payment, payment_id)


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
