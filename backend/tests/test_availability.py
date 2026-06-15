"""Unit tests for ``app.core.availability``."""

from datetime import datetime

from app.core.library_sessions import LIBRARY_TIMEZONE
from app.core.availability import (
    AVAILABLE,
    ON_LOAN,
    RESERVED,
    UNAVAILABLE,
    UNKNOWN,
    member_availability,
    normalize_availability,
)


def test_normalize_from_seed_csv_statuses() -> None:
    assert normalize_availability("In library") == AVAILABLE
    assert normalize_availability("On loan") == ON_LOAN
    assert normalize_availability("On loan (overdue)") == ON_LOAN
    assert normalize_availability("Being repaired") == UNAVAILABLE
    assert normalize_availability("Missing") == UNAVAILABLE
    assert normalize_availability("Joined with another toy") == UNAVAILABLE


def test_normalize_empty_and_unknown() -> None:
    assert normalize_availability(None) == UNKNOWN
    assert normalize_availability("") == UNKNOWN
    assert normalize_availability("   ") == UNKNOWN
    assert normalize_availability("Mystery status XYZ") == UNKNOWN


def test_normalize_case_insensitive() -> None:
    assert normalize_availability("IN LIBRARY") == AVAILABLE
    assert normalize_availability("on LOAN") == ON_LOAN


def test_reserved_keywords() -> None:
    assert normalize_availability("Reserved for pickup") == RESERVED
    assert normalize_availability("On hold") == RESERVED


def test_canonical_codes_are_accepted() -> None:
    assert normalize_availability(AVAILABLE) == AVAILABLE
    assert normalize_availability(ON_LOAN) == ON_LOAN
    assert normalize_availability(RESERVED) == RESERVED
    assert normalize_availability(UNAVAILABLE) == UNAVAILABLE
    assert normalize_availability(UNKNOWN) == UNKNOWN


def test_member_availability_active_loan_overrides_reserved() -> None:
    assert member_availability("Reserved", has_active_loan=True) == ON_LOAN
    assert member_availability("On loan", has_active_loan=True) == ON_LOAN
    assert member_availability("In library", has_active_loan=True) == ON_LOAN
    assert (
        member_availability(
            "Reserved",
            has_active_loan=False,
            has_pending_booking=True,
        )
        == RESERVED
    )
    assert member_availability("In library", has_active_loan=False) == AVAILABLE
    assert member_availability("On loan", has_active_loan=False) == AVAILABLE
    assert member_availability("Reserved", has_active_loan=False) == AVAILABLE


def test_member_availability_on_loan_with_pending_queue_shows_reserved() -> None:
    assert (
        member_availability(
            "On loan",
            has_active_loan=True,
            has_pending_booking=True,
        )
        == RESERVED
    )


def test_member_availability_on_loan_with_expired_queue_hold_shows_on_loan() -> None:
    """After the two-week hold, another member may book even if a stale pending row exists."""
    from app.core.reservation_hold import pending_queue_blocks_new_booking

    pending = type(
        "Pending",
        (),
        {"created_at": datetime(2026, 6, 8, 12, 0, tzinfo=LIBRARY_TIMEZONE)},
    )()
    assert not pending_queue_blocks_new_booking(
        pending,
        now=datetime(2026, 6, 24, 12, 0, tzinfo=LIBRARY_TIMEZONE),
    )
