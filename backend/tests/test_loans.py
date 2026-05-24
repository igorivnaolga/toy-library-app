import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.models.loan import DEFAULT_LOAN_DAYS, LOAN_STATUS_ACTIVE, LOAN_STATUS_RETURNED
from app.services.loan_service import (
    LoanError,
    check_in_loan,
    check_out_from_booking,
    loan_is_overdue,
    renew_loan_for_user,
)


def _loan(
    *,
    status: str = LOAN_STATUS_ACTIVE,
    due_date: date | None = None,
    renewal_count: int = 0,
) -> SimpleNamespace:
    return SimpleNamespace(
        status=status,
        due_date=due_date or date(2026, 5, 19),
        renewal_count=renewal_count,
    )


def test_loan_is_overdue_when_active_and_past_due() -> None:
    loan = _loan(due_date=date(2026, 5, 1))
    assert loan_is_overdue(loan, today=date(2026, 5, 19)) is True


def test_loan_is_not_overdue_when_due_today() -> None:
    loan = _loan(due_date=date(2026, 5, 19))
    assert loan_is_overdue(loan, today=date(2026, 5, 19)) is False


def test_loan_is_not_overdue_when_returned() -> None:
    loan = _loan(status=LOAN_STATUS_RETURNED, due_date=date(2026, 5, 1))
    assert loan_is_overdue(loan, today=date(2026, 5, 19)) is False


def test_default_loan_period_is_fourteen_days() -> None:
    assert DEFAULT_LOAN_DAYS == 14


def test_check_out_from_booking_raises_when_not_pending() -> None:
    session = MagicMock()
    booking = SimpleNamespace(
        id=uuid.uuid4(),
        status="completed",
        pickup_date=date(2026, 5, 19),
        toy_id="T1",
        user_id=uuid.uuid4(),
        toy=None,
    )
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(
            "app.services.loan_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        with pytest.raises(LoanError) as exc:
            check_out_from_booking(session, booking.id)
    assert exc.value.code == "booking_not_checkoutable"


def test_renew_loan_raises_when_renewals_exhausted() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    loan_id = uuid.uuid4()
    loan = SimpleNamespace(
        id=loan_id,
        user_id=user_id,
        status=LOAN_STATUS_ACTIVE,
        due_date=date(2026, 5, 19),
        renewal_count=2,
        toy_id="T1",
        toy=SimpleNamespace(category_id=1),
    )
    category = SimpleNamespace(max_renewals=2)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.loan_service.get_loan_by_id", lambda _s, _id: loan)
        session.get = MagicMock(return_value=category)
        with pytest.raises(LoanError) as exc:
            renew_loan_for_user(session, user_id, loan_id)
    assert exc.value.code == "renewals_exhausted"


def test_check_in_raises_when_loan_not_active() -> None:
    session = MagicMock()
    loan_id = uuid.uuid4()
    loan = SimpleNamespace(
        id=loan_id,
        status=LOAN_STATUS_RETURNED,
        toy_id="T1",
        toy=None,
    )
    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.loan_service.get_loan_by_id", lambda _s, _id: loan)
        with pytest.raises(LoanError) as exc:
            check_in_loan(session, loan_id)
    assert exc.value.code == "loan_not_active"
