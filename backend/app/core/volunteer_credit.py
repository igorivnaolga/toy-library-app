"""Volunteer duty shift hire credit (library policy)."""

from __future__ import annotations

from datetime import date

VOLUNTEER_DUTY_CREDIT_CENTS = 500


def volunteer_duty_credit_description(session_date: date) -> str:
    """Human-readable payment row label for a confirmed duty shift."""
    return f"Volunteer duty credit — {session_date.strftime('%a %d %b %Y')}"
