"""Bounds for ``from``/``to`` query ranges on calendar endpoints."""

from __future__ import annotations

from datetime import date

from fastapi import HTTPException

# Mobile loads at most ~410 days at once (45 days back + 365 ahead).
MAX_RANGE_DAYS = 425


def require_bounded_range(from_date: date, to_date: date) -> None:
    """422 when ``to`` precedes ``from`` or the span exceeds ``MAX_RANGE_DAYS``."""
    if to_date < from_date:
        raise HTTPException(status_code=422, detail="`to` must be on or after `from`.")
    if (to_date - from_date).days > MAX_RANGE_DAYS:
        raise HTTPException(
            status_code=422,
            detail=f"Date range cannot exceed {MAX_RANGE_DAYS} days.",
        )
