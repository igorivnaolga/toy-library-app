"""Booking pickup-window rules."""

from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.core.library_sessions import LIBRARY_TIMEZONE, bookable_horizon_end
from app.services.booking_service import BookingError, create_booking_for_user, list_pickup_date_options


def _dt(y: int, m: int, d: int, hh: int = 9, mm: int = 0):
    from datetime import datetime

    return datetime(y, m, d, hh, mm, tzinfo=LIBRARY_TIMEZONE)


def test_pickup_dates_extend_when_loan_ends_beyond_six_months() -> None:
    """On-loan toys still offer sessions after the normal 6-month horizon."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="On loan")
    loan = SimpleNamespace(due_date=date(2026, 7, 10))

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 8))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 7, 11)
    assert all(opt["date"] >= date(2026, 7, 11) for opt in options)
    assert options[-1]["date"] <= bookable_horizon_end(date(2026, 7, 11))


def test_pickup_dates_skip_due_session_day() -> None:
    """When the loan is due on a session day, booking starts the following session."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="On loan")
    loan = SimpleNamespace(due_date=date(2026, 7, 11))

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 8))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 7, 15)
    assert date(2026, 7, 11) not in [opt["date"] for opt in options]


def test_pickup_dates_for_reserved_toy_with_active_loan() -> None:
    """Reserved toys use the later of loan-end and two-week reservation hold."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    loan = SimpleNamespace(due_date=date(2026, 7, 10))
    pending = SimpleNamespace(
        pickup_date=date(2026, 7, 11),
        created_at=_dt(2026, 6, 8),
    )

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 8))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 7, 11)
    assert date(2026, 6, 24) not in [opt["date"] for opt in options]


def test_pickup_dates_for_reserved_toy_after_loan_returned() -> None:
    """Reserved toys keep a 6-month reschedule window from the booked pickup day."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        pickup_date=date(2027, 1, 13),
        created_at=_dt(2026, 6, 8),
    )

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 8))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 6, 24)
    assert date(2027, 1, 13) in [opt["date"] for opt in options]
    assert options[-1]["date"] <= bookable_horizon_end(date(2027, 1, 13))


def test_pickup_dates_for_available_toy_start_at_next_session() -> None:
    """New bookings on available toys can start from the next open session."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="In library")

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 8))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: None,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 6, 10)


def test_create_booking_allows_reserved_toy_with_active_loan() -> None:
    """Members can queue pickup after the current loan even when status is Reserved."""
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    loan = SimpleNamespace(due_date=date(2026, 7, 10), user_id=other_user_id)
    booking = SimpleNamespace(id=uuid.uuid4())

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr("app.services.booking_service._validate_pickup_date", lambda *a, **k: None)
        mp.setattr(
            "app.services.booking_service.create_booking",
            lambda *a, **k: booking,
        )
        mp.setattr(
            "app.services.booking_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        result = create_booking_for_user(
            session,
            user_id,
            "1000",
            date(2026, 7, 15),
        )

    assert result is booking
    assert toy.status == "Reserved"


def test_create_booking_allows_on_loan_toy_with_active_loan() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="On loan")
    loan = SimpleNamespace(due_date=date(2026, 7, 10), user_id=other_user_id)
    booking = SimpleNamespace(id=uuid.uuid4())

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr("app.services.booking_service._validate_pickup_date", lambda *a, **k: None)
        mp.setattr(
            "app.services.booking_service.create_booking",
            lambda *a, **k: booking,
        )
        mp.setattr(
            "app.services.booking_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        result = create_booking_for_user(
            session,
            user_id,
            "1000",
            date(2026, 7, 15),
        )

    assert result is booking
    assert toy.status == "On loan"


def test_create_booking_blocked_during_reservation_hold() -> None:
    """Pickup before the two-week hold session is rejected."""
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        user_id=other_user_id,
        created_at=_dt(2026, 6, 8),
        pickup_date=date(2026, 7, 11),
    )

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.core.reservation_hold.library_now", lambda: _dt(2026, 6, 10))
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        with pytest.raises(BookingError) as exc:
            create_booking_for_user(
                session,
                user_id,
                "1000",
                date(2026, 6, 10),
            )
    assert exc.value.code == "pickup_before_loan_due"
    assert "Wednesday 24 June" in exc.value.message


def test_create_booking_during_hold_with_valid_pickup_replaces_pending() -> None:
    """Members may book ahead if pickup is on or after the hold session."""
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        user_id=other_user_id,
        created_at=_dt(2026, 6, 8),
        pickup_date=date(2026, 7, 11),
    )
    booking = SimpleNamespace(id=uuid.uuid4())
    cancelled: list[object] = []

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.core.reservation_hold.library_now", lambda: _dt(2026, 6, 10))
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        mp.setattr("app.services.booking_service._validate_pickup_date", lambda *a, **k: None)
        mp.setattr(
            "app.services.booking_service.mark_booking_cancelled",
            lambda _s, row: cancelled.append(row),
        )
        mp.setattr(
            "app.services.booking_service.create_booking",
            lambda *a, **k: booking,
        )
        mp.setattr(
            "app.services.booking_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        result = create_booking_for_user(
            session,
            user_id,
            "1000",
            date(2026, 6, 24),
        )

    assert result is booking
    assert cancelled == [pending]


def test_create_booking_after_hold_replaces_existing_pending() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        user_id=other_user_id,
        created_at=_dt(2026, 6, 8),
        pickup_date=date(2026, 7, 11),
    )
    booking = SimpleNamespace(id=uuid.uuid4())
    cancelled: list[object] = []

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.core.reservation_hold.library_now", lambda: _dt(2026, 6, 24))
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        mp.setattr("app.services.booking_service._validate_pickup_date", lambda *a, **k: None)
        mp.setattr(
            "app.services.booking_service.mark_booking_cancelled",
            lambda _s, row: cancelled.append(row),
        )
        mp.setattr(
            "app.services.booking_service.create_booking",
            lambda *a, **k: booking,
        )
        mp.setattr(
            "app.services.booking_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        result = create_booking_for_user(
            session,
            user_id,
            "1000",
            date(2026, 6, 24),
        )

    assert result is booking
    assert cancelled == [pending]
    assert toy.status == "Reserved"


def test_create_booking_after_hold_requires_pickup_from_hold_session() -> None:
    """Replacing a reservation cannot pick up before the prior hold window ends."""
    session = MagicMock()
    user_id = uuid.uuid4()
    other_user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        user_id=other_user_id,
        created_at=_dt(2026, 6, 8),
        pickup_date=date(2026, 7, 11),
    )

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.core.reservation_hold.library_now", lambda: _dt(2026, 6, 24))
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        mp.setattr(
            "app.services.booking_service.mark_booking_cancelled",
            lambda _s, _row: None,
        )
        with pytest.raises(BookingError) as exc:
            create_booking_for_user(
                session,
                user_id,
                "1000",
                date(2026, 6, 10),
            )
    assert exc.value.code == "pickup_before_loan_due"
    assert "Wednesday 24 June" in exc.value.message


def test_pickup_dates_after_hold_open_at_prior_reservation_session() -> None:
    """Once the hold ends, pickup choices start at the next session after two weeks."""
    session = MagicMock()
    toy = SimpleNamespace(toy_id="1000", status="Reserved")
    pending = SimpleNamespace(
        created_at=_dt(2026, 6, 8),
        pickup_date=date(2026, 7, 11),
    )

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.core.reservation_hold.library_now", lambda: _dt(2026, 6, 24))
        mp.setattr("app.services.booking_service.library_now", lambda: _dt(2026, 6, 24))
        mp.setattr(
            "app.services.booking_service._get_toy_row",
            lambda _s, _id: toy,
        )
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        options = list_pickup_date_options(session, toy_id="1000")

    assert options
    assert options[0]["date"] == date(2026, 6, 24)


def test_create_booking_allows_on_loan_status_without_active_loan_row() -> None:
    """Stale on-loan inventory labels without a loans row can still be booked."""
    session = MagicMock()
    user_id = uuid.uuid4()
    toy = SimpleNamespace(toy_id="1000", status="On loan")
    booking = SimpleNamespace(id=uuid.uuid4())

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr("app.services.booking_service._run_booking_maintenance", lambda _s: None)
        mp.setattr("app.services.booking_service._get_toy_row", lambda _s, _id: toy)
        mp.setattr(
            "app.services.booking_service.get_active_loan_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr(
            "app.services.booking_service.get_pending_booking_for_toy",
            lambda _s, _toy: None,
        )
        mp.setattr("app.services.booking_service._validate_pickup_date", lambda *a, **k: None)
        mp.setattr(
            "app.services.booking_service.create_booking",
            lambda *a, **k: booking,
        )
        mp.setattr(
            "app.services.booking_service.get_booking_by_id",
            lambda _s, _id: booking,
        )
        result = create_booking_for_user(
            session,
            user_id,
            "1000",
            date(2026, 6, 24),
        )

    assert result is booking
    assert toy.status == "Reserved"
