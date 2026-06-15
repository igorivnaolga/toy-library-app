"""Admin-only enrichment for single-toy detail responses."""

from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.core.library_sessions import format_pickup_label
from app.repositories.booking_repo import get_pending_booking_for_toy
from app.repositories.loan_repo import get_active_loan_for_toy
from app.repositories.profile_repo import get_user_display_map
from app.schemas.toy import ToyOut
from app.utils.text import visible_member_name


def enrich_toy_out_for_admin(session: Session, toy: ToyOut) -> ToyOut:
    """Attach reservation and active-loan member context for admin toy detail."""
    updates: dict[str, str | None] = {}

    pending = get_pending_booking_for_toy(session, toy.toy_id)
    loan = get_active_loan_for_toy(session, toy.toy_id)

    user_ids: set[uuid.UUID] = set()
    if pending is not None:
        user_ids.add(pending.user_id)
    if loan is not None:
        user_ids.add(loan.user_id)

    display_map = get_user_display_map(session, user_ids) if user_ids else {}

    if pending is not None:
        full_name, email = display_map.get(pending.user_id, ("", ""))
        if not full_name.strip():
            profile = getattr(pending, "profile", None)
            if profile is not None and profile.full_name:
                full_name = profile.full_name
        cleaned_name = full_name.strip() or None
        cleaned_email = email.strip() or None
        updates["reserved_by_name"] = visible_member_name(cleaned_name, cleaned_email)
        updates["reserved_by_email"] = cleaned_email
        if pending.pickup_date is not None:
            updates["reservation_pickup_label"] = format_pickup_label(
                pending.pickup_date
            )

    if loan is not None:
        full_name, email = display_map.get(loan.user_id, ("", ""))
        if not full_name.strip():
            profile = getattr(loan, "profile", None)
            if profile is not None and profile.full_name:
                full_name = profile.full_name
        cleaned_name = full_name.strip() or None
        cleaned_email = email.strip() or None
        updates["on_loan_to_name"] = visible_member_name(cleaned_name, cleaned_email)
        updates["on_loan_to_email"] = cleaned_email
        if loan.due_date is not None:
            updates["loan_due_label"] = format_pickup_label(loan.due_date)

    if not updates:
        return toy
    return toy.model_copy(update=updates)
