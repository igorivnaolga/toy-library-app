"""Race conditions and database constraints, against real Postgres."""

from __future__ import annotations

import uuid
from datetime import date, time

import pytest
from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError

from app.core.library_sessions import allowed_pickup_dates
from app.core.roles import Role
from app.models.booking import Booking
from app.models.duty_session import DutySession
from app.models.library_event import EventBooking, EventTimeSlot, LibraryEvent
from app.models.loan import Loan
from app.models.payment import Payment
from app.repositories.duty_repo import claim_duty_session
from app.services.booking_service import BookingError, create_booking_for_user
from app.services.duty_service import ensure_roster_sessions
from app.services.event_service import EventError, book_slot_service
from app.services.loan_service import LoanError, check_in_loan, check_out_walk_in
from app.services.payment_service import record_top_up

from .conftest import run_concurrently

pytestmark = pytest.mark.integration


def _errors(results, kind):
    return [r for r in results if isinstance(r, kind)]


def test_two_volunteers_cannot_both_claim_a_duty_slot(session_factory, make_user) -> None:
    a, b = make_user("volunteer", "duty"), make_user("volunteer", "duty")
    with session_factory() as s:
        slot = DutySession(session_date=date(2030, 1, 2), start_time=time(13), end_time=time(14, 30))
        s.add(slot)
        s.commit()
        slot_id = slot.id

    results = run_concurrently(
        session_factory,
        lambda s: claim_duty_session(s, slot_id, a),
        lambda s: claim_duty_session(s, slot_id, b),
    )

    assert sorted(results) == [False, True]
    with session_factory() as s:
        winner = s.get(DutySession, slot_id).volunteer_id
    assert winner == (a if results[0] else b)


def test_concurrent_roster_generation_creates_each_day_once(session_factory) -> None:
    today = date(2030, 1, 1)
    start, end = date(2030, 1, 1), date(2030, 1, 31)
    run_concurrently(
        session_factory,
        lambda s: ensure_roster_sessions(s, from_date=start, to_date=end, today=today),
        lambda s: ensure_roster_sessions(s, from_date=start, to_date=end, today=today),
    )
    with session_factory() as s:
        rows = s.scalars(select(DutySession.session_date)).all()
    assert len(rows) == len(set(rows)) == 9  # Wed/Sat in January 2030


def test_event_slot_capacity_holds_under_concurrency(
    session_factory, make_user, monkeypatch: pytest.MonkeyPatch
) -> None:
    import time as _time

    from app.services import event_service

    # Widen the check-then-insert window so a missing lock fails deterministically.
    real_count = event_service.count_bookings_for_slot

    def slow_count(session, slot_id):
        count = real_count(session, slot_id)
        _time.sleep(0.3)
        return count

    monkeypatch.setattr(event_service, "count_bookings_for_slot", slow_count)
    users = [make_user("member") for _ in range(3)]
    with session_factory() as s:
        event = LibraryEvent(
            name="Toy swap", event_date=date(2030, 3, 2), end_date=date(2030, 3, 2), is_published=True
        )
        s.add(event)
        s.flush()
        slot = EventTimeSlot(
            event_id=event.id, start_time=time(10), end_time=time(11), capacity=1, audience="member"
        )
        s.add(slot)
        s.commit()
        slot_id = slot.id

    results = run_concurrently(
        session_factory,
        *[
            (lambda uid: lambda s: book_slot_service(s, slot_id=slot_id, user_id=uid, role=Role.MEMBER))(u)
            for u in users
        ],
    )

    assert len(_errors(results, EventError)) == 2
    assert {e.code for e in _errors(results, EventError)} == {"full"}
    with session_factory() as s:
        assert s.scalar(select(func.count()).select_from(EventBooking)) == 1


def test_same_toy_cannot_be_checked_out_twice(session_factory, make_user, make_toy) -> None:
    staff = make_user("admin", None)
    a, b = make_user("member"), make_user("member")
    toy_id = make_toy("T1")

    results = run_concurrently(
        session_factory,
        lambda s: check_out_walk_in(s, user_id=a, toy_id=toy_id, recorded_by=staff),
        lambda s: check_out_walk_in(s, user_id=b, toy_id=toy_id, recorded_by=staff),
    )

    errors = _errors(results, LoanError)
    assert len(errors) == 1
    assert errors[0].code == "toy_on_loan"
    with session_factory() as s:
        assert s.scalar(select(func.count()).select_from(Loan).where(Loan.status == "active")) == 1


def test_loan_cannot_be_returned_twice(session_factory, make_user, make_toy) -> None:
    staff, member = make_user("admin", None), make_user("member")
    toy_id = make_toy("T2")
    with session_factory() as s:
        loan = check_out_walk_in(s, user_id=member, toy_id=toy_id, recorded_by=staff)
        s.commit()
        loan_id = loan.id

    results = run_concurrently(
        session_factory,
        lambda s: check_in_loan(s, loan_id),
        lambda s: check_in_loan(s, loan_id),
    )

    errors = _errors(results, LoanError)
    assert len(errors) == 1
    assert errors[0].code == "loan_not_active"


def test_same_toy_cannot_be_booked_twice(session_factory, make_user, make_toy) -> None:
    a, b = make_user("member"), make_user("member")
    toy_id = make_toy("T3")
    pickup = allowed_pickup_dates()[1]

    results = run_concurrently(
        session_factory,
        lambda s: create_booking_for_user(s, a, toy_id, pickup),
        lambda s: create_booking_for_user(s, b, toy_id, pickup),
    )

    assert len(_errors(results, BookingError)) == 1
    with session_factory() as s:
        pending = s.scalar(
            select(func.count()).select_from(Booking).where(Booking.status == "pending")
        )
    assert pending == 1


def test_retried_top_up_is_recorded_once(session_factory, make_user) -> None:
    staff, member = make_user("admin", None), make_user("member")
    key = "retry-" + uuid.uuid4().hex

    results = run_concurrently(
        session_factory,
        lambda s: record_top_up(s, member, amount_cents=2000, method="cash", recorded_by=staff, idempotency_key=key),
        lambda s: record_top_up(s, member, amount_cents=2000, method="cash", recorded_by=staff, idempotency_key=key),
    )

    assert not [r for r in results if isinstance(r, Exception)], results
    with session_factory() as s:
        count = s.scalar(
            select(func.count()).select_from(Payment).where(Payment.payment_type == "top_up")
        )
    assert count == 1


def test_profile_with_payment_history_cannot_be_deleted(session_factory, make_user) -> None:
    staff, member = make_user("admin", None), make_user("member")
    with session_factory() as s:
        record_top_up(s, member, amount_cents=500, method="cash", recorded_by=staff)
        s.commit()

    with session_factory() as s:
        with pytest.raises(IntegrityError):
            s.execute(text("DELETE FROM auth.users WHERE id = :id"), {"id": member})
            s.flush()
