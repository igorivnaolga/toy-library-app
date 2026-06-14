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
    credit_balance_cents,
    grant_volunteer_duty_credit,
    apply_existing_credit_to_pending_charges,
    mark_payments_paid,
    membership_payment_summary,
    record_top_up,
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
    assert summary.credit_balance_cents == 0


def test_balance_summary_applies_account_credit() -> None:
    session = MagicMock()
    pending = [
        SimpleNamespace(payment_type="rental", amount_cents=500),
    ]
    with patch(
        "app.services.payment_service.list_pending_payments",
        return_value=pending,
    ), patch(
        "app.services.payment_service.credit_balance_cents",
        return_value=300,
    ):
        summary = balance_summary(session, uuid.uuid4())
    assert summary.balance_due_cents == 200
    assert summary.credit_balance_cents == 300


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


def test_record_top_up_applies_credit_to_pending_charges() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    recorded_by = uuid.uuid4()
    pending_rental = SimpleNamespace(
        id=uuid.uuid4(),
        amount_cents=500,
        status="pending",
    )
    with patch(
        "app.services.payment_service.create_recorded_payment",
        return_value=SimpleNamespace(id=uuid.uuid4()),
    ) as create_mock, patch(
        "app.services.payment_service.list_pending_payments",
        return_value=[pending_rental],
    ), patch(
        "app.services.payment_service.mark_payment_status",
    ) as mark_mock:
        record_top_up(
            session,
            user_id,
            amount_cents=1000,
            method="cash",
            recorded_by=recorded_by,
        )
    create_mock.assert_called_once()
    assert create_mock.call_args.kwargs["payment_type"] == "top_up"
    assert create_mock.call_args.kwargs["amount_cents"] == 1000
    mark_mock.assert_called_once()
    assert mark_mock.call_args.kwargs["status"] == "paid_credit"


def test_apply_existing_credit_to_pending_charges() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    recorded_by = uuid.uuid4()
    pending_rental = SimpleNamespace(
        id=uuid.uuid4(),
        amount_cents=500,
        status="pending",
    )
    with patch(
        "app.services.payment_service.credit_balance_cents",
        return_value=500,
    ), patch(
        "app.services.payment_service.list_pending_payments",
        return_value=[pending_rental],
    ), patch(
        "app.services.payment_service.mark_payment_status",
    ) as mark_mock:
        applied = apply_existing_credit_to_pending_charges(
            session,
            user_id,
            recorded_by=recorded_by,
        )
    assert applied == 500
    mark_mock.assert_called_once()


def test_grant_volunteer_duty_credit_is_idempotent() -> None:
    session = MagicMock()
    duty_session = SimpleNamespace(
        id=uuid.uuid4(),
        volunteer_id=uuid.uuid4(),
        session_date=__import__("datetime").date(2026, 6, 14),
    )
    existing = SimpleNamespace(id=uuid.uuid4())
    with patch(
        "app.services.payment_service.get_volunteer_credit_for_duty_session",
        return_value=existing,
    ), patch(
        "app.services.payment_service.create_recorded_payment",
    ) as create_mock:
        result = grant_volunteer_duty_credit(
            session,
            duty_session,
            recorded_by=uuid.uuid4(),
        )
    assert result is existing
    create_mock.assert_not_called()


def test_mark_payments_paid_marks_selected_pending_rows() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    recorded_by = uuid.uuid4()
    payment_a = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        status="pending",
    )
    payment_b = SimpleNamespace(
        id=uuid.uuid4(),
        user_id=user_id,
        status="pending",
    )

    def _get_payment(_session, payment_id):
        if payment_id == payment_a.id:
            return payment_a
        if payment_id == payment_b.id:
            return payment_b
        return None

    with patch(
        "app.services.payment_service.get_payment_by_id",
        side_effect=_get_payment,
    ), patch(
        "app.services.payment_service.mark_payment_status",
        side_effect=lambda _session, payment, **kwargs: payment,
    ) as mark_mock:
        updated = mark_payments_paid(
            session,
            user_id,
            [payment_a.id, payment_b.id],
            method="cash",
            recorded_by=recorded_by,
        )

    assert updated == [payment_a, payment_b]
    assert mark_mock.call_count == 2


def test_mark_payments_paid_rejects_empty_selection() -> None:
    session = MagicMock()
    with pytest.raises(PaymentError) as exc:
        mark_payments_paid(
            session,
            uuid.uuid4(),
            [],
            method="cash",
            recorded_by=uuid.uuid4(),
        )
    assert exc.value.code == "no_payments_selected"
