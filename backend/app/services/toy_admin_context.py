"""Admin-only enrichment for single-toy detail responses."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.core.library_sessions import format_pickup_label
from app.repositories.booking_repo import get_pending_booking_for_toy
from app.repositories.loan_repo import get_active_loan_for_toy
from app.repositories.profile_repo import get_user_email
from app.schemas.toy import ToyOut
from app.utils.text import visible_member_name


def enrich_toy_out_for_admin(session: Session, toy: ToyOut) -> ToyOut:
    """Attach reservation and active-loan member context for admin toy detail."""
    updates: dict[str, str | None] = {}

    pending = get_pending_booking_for_toy(session, toy.toy_id)
    if pending is not None:
        email = get_user_email(session, pending.user_id)
        profile = getattr(pending, "profile", None)
        name = profile.full_name if profile is not None else None
        updates["reserved_by_name"] = visible_member_name(name, email)
        updates["reserved_by_email"] = email
        if pending.pickup_date is not None:
            updates["reservation_pickup_label"] = format_pickup_label(
                pending.pickup_date
            )

    loan = get_active_loan_for_toy(session, toy.toy_id)
    if loan is not None:
        email = get_user_email(session, loan.user_id)
        profile = getattr(loan, "profile", None)
        name = profile.full_name if profile is not None else None
        updates["on_loan_to_name"] = visible_member_name(name, email)
        updates["on_loan_to_email"] = email
        if loan.due_date is not None:
            updates["loan_due_label"] = format_pickup_label(loan.due_date)

    if not updates:
        return toy
    return toy.model_copy(update=updates)
