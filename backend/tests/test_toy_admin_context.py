"""Tests for admin-only toy detail enrichment."""

from __future__ import annotations

import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock

from app.schemas.toy import ToyOut
from app.services.toy_admin_context import enrich_toy_out_for_admin


def test_enrich_toy_out_for_admin_includes_reservation_and_loan() -> None:
    session = MagicMock()
    user_reserved = uuid.uuid4()
    user_borrower = uuid.uuid4()
    pending = SimpleNamespace(
        user_id=user_reserved,
        pickup_date=date(2026, 6, 17),
        profile=SimpleNamespace(full_name="Alex Member"),
    )
    loan = SimpleNamespace(
        user_id=user_borrower,
        due_date=date(2026, 7, 1),
        profile=SimpleNamespace(full_name="Jamie Borrower"),
    )
    toy = ToyOut(toy_id="1001", name="Blocks")

    def _display_map(_session, user_ids):
        mapping = {
            user_reserved: ("Alex Member", "alex@example.com"),
            user_borrower: ("Jamie Borrower", "jamie@example.com"),
        }
        return {uid: mapping[uid] for uid in user_ids if uid in mapping}

    with __import__("pytest").MonkeyPatch.context() as mp:
        mp.setattr(
            "app.services.toy_admin_context.get_pending_booking_for_toy",
            lambda _s, _toy: pending,
        )
        mp.setattr(
            "app.services.toy_admin_context.get_active_loan_for_toy",
            lambda _s, _toy: loan,
        )
        mp.setattr(
            "app.services.toy_admin_context.get_user_display_map",
            _display_map,
        )
        enriched = enrich_toy_out_for_admin(session, toy)

    assert enriched.reserved_by_name == "Alex Member"
    assert enriched.reserved_by_email == "alex@example.com"
    assert enriched.reservation_pickup_label == "Wednesday 17 June"
    assert enriched.on_loan_to_name == "Jamie Borrower"
    assert enriched.on_loan_to_email == "jamie@example.com"
    assert enriched.loan_due_label == "Wednesday 01 July"
