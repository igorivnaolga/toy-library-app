"""Unit tests for ``app.core.availability``."""

from app.core.availability import (
    AVAILABLE,
    ON_LOAN,
    RESERVED,
    UNAVAILABLE,
    UNKNOWN,
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
