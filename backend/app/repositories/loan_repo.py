"""Data access for ``public.loans``."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models.loan import LOAN_STATUS_ACTIVE, LOAN_STATUS_RETURNED, Loan
from app.models.toy import Toy


def create_loan(
    session: Session,
    *,
    user_id: uuid.UUID,
    toy_id: str,
    due_date: date,
    booking_id: uuid.UUID | None = None,
    checked_out_at: datetime | None = None,
) -> Loan:
    loan = Loan(
        user_id=user_id,
        toy_id=toy_id,
        booking_id=booking_id,
        due_date=due_date,
        status=LOAN_STATUS_ACTIVE,
    )
    if checked_out_at is not None:
        loan.checked_out_at = checked_out_at
    session.add(loan)
    session.flush()
    return loan


def get_loan_by_id(session: Session, loan_id: uuid.UUID) -> Loan | None:
    return session.scalar(
        select(Loan)
        .options(
            joinedload(Loan.toy).joinedload(Toy.image),
            joinedload(Loan.profile),
        )
        .where(Loan.id == loan_id)
    )


def get_active_loan_for_toy(session: Session, toy_id: str) -> Loan | None:
    return session.scalar(
        select(Loan)
        .options(joinedload(Loan.toy).joinedload(Toy.image))
        .where(
            Loan.toy_id == toy_id,
            Loan.status == LOAN_STATUS_ACTIVE,
        )
    )


def get_active_loan_for_user_toy(
    session: Session,
    user_id: uuid.UUID,
    toy_id: str,
) -> Loan | None:
    return session.scalar(
        select(Loan).where(
            Loan.user_id == user_id,
            Loan.toy_id == toy_id,
            Loan.status == LOAN_STATUS_ACTIVE,
        )
    )


def list_loans_for_user(
    session: Session,
    user_id: uuid.UUID,
    *,
    active_only: bool = False,
) -> list[Loan]:
    stmt = (
        select(Loan)
        .options(joinedload(Loan.toy).joinedload(Toy.image))
        .where(Loan.user_id == user_id)
        .order_by(Loan.checked_out_at.desc())
    )
    if active_only:
        stmt = stmt.where(Loan.status == LOAN_STATUS_ACTIVE)
    return list(session.scalars(stmt).unique().all())


def list_active_loans(session: Session) -> list[Loan]:
    return list(
        session.scalars(
            select(Loan)
            .options(
                joinedload(Loan.toy).joinedload(Toy.image),
                joinedload(Loan.profile),
            )
            .where(Loan.status == LOAN_STATUS_ACTIVE)
            .order_by(Loan.due_date.asc(), Loan.checked_out_at.asc())
        )
        .unique()
        .all()
    )


def mark_loan_returned(session: Session, loan: Loan) -> Loan:
    loan.status = LOAN_STATUS_RETURNED
    loan.returned_at = datetime.now(timezone.utc)
    session.flush()
    return loan


def extend_loan_due_date(session: Session, loan: Loan, new_due_date: date) -> Loan:
    loan.due_date = new_due_date
    loan.renewal_count += 1
    session.flush()
    return loan
