"""Payment ledger rules."""

from __future__ import annotations

import uuid
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import pytest

from app.core.membership_fees import CASUAL_BOND_CENTS, MEMBERSHIP_FEE_CENTS, charges_for_tier
from app.services.payment_service import (
    PaymentError,
    assert_membership_paid_for_booking,
    balance_summary,
    create_membership_payments_for_tier,
    membership_payment_summary,
)


def test_charges_for_tier_duty() -> None:
    rows = charges_for_tier("duty")
    assert rows == [("membership", MEMBERSHIP_FEE_CENTS["duty"], "Duty membership")]


def test_charges_for_tier_casual_includes_bond() -> None:
    rows = charges_for_tier("casual")
    assert len(rows) == 2
    assert rows[0][1] == MEMBERSHIP_FEE_CENTS["casual"]
    assert rows[1] == ("bond", CASUAL_BOND_CENTS, "Casual refundable bond")


def test_membership_payment_summary_when_pending() -> None:
    session = MagicMock()
    pending = [
        SimpleNamespace(amount_cents=6500),
        SimpleNamespace(amount_cents=5000),
    ]
    with patch(
        "app.services.payment_service.list_pending_membership_payments",
        return_value=pending,
    ):
        summary = membership_payment_summary(session, uuid.uuid4())
    assert summary.due_cents == 11500
    assert summary.fees_paid is False
    assert summary.pending_count == 2


def test_membership_payment_summary_when_clear() -> None:
    session = MagicMock()
    with patch(
        "app.services.payment_service.list_pending_membership_payments",
        return_value=[],
    ):
        summary = membership_payment_summary(session, uuid.uuid4())
    assert summary.due_cents == 0
    assert summary.fees_paid is True


def test_assert_membership_paid_raises_when_due() -> None:
    session = MagicMock()
    with patch(
        "app.services.payment_service.list_pending_membership_payments",
        return_value=[SimpleNamespace(amount_cents=15000)],
    ):
        with pytest.raises(PaymentError) as exc:
            assert_membership_paid_for_booking(session, uuid.uuid4())
    assert exc.value.code == "membership_unpaid"


def test_balance_summary_splits_membership_and_rental() -> None:
    session = MagicMock()
    pending = [
        SimpleNamespace(payment_type="membership", amount_cents=6500),
        SimpleNamespace(payment_type="rental", amount_cents=50),
        SimpleNamespace(payment_type="rental", amount_cents=75),
    ]
    with patch(
        "app.services.payment_service.list_pending_payments",
        return_value=pending,
    ):
        summary = balance_summary(session, uuid.uuid4())
    assert summary.membership_due_cents == 6500
    assert summary.rental_due_cents == 125
    assert summary.balance_due_cents == 6625


def test_create_membership_payments_for_tier_calls_repo() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    with patch("app.services.payment_service.create_payment") as create_mock:
        create_mock.side_effect = lambda *args, **kwargs: SimpleNamespace(
            id=uuid.uuid4()
        )
        payments = create_membership_payments_for_tier(session, user_id, "non_duty")
    assert len(payments) == 1
    create_mock.assert_called_once()
    assert create_mock.call_args.kwargs["amount_cents"] == 15000
