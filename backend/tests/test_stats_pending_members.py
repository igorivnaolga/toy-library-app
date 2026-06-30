"""Pending member stats use net balance due (charges minus credit)."""

from __future__ import annotations

import uuid
from unittest.mock import MagicMock

import pytest

from app.services.payment_service import BalanceSummary
from app.services.stats_period import resolve_stats_period
from app.services.stats_service import pending_members_in_period


def test_pending_members_uses_net_balance_after_credit() -> None:
    session = MagicMock()
    user_id = uuid.uuid4()
    period = resolve_stats_period(period="month", year=2026, month=6)

    session.scalars.return_value.all.return_value = [user_id]

    balances = {
        user_id: BalanceSummary(
            balance_due_cents=750,
            membership_due_cents=10_000,
            rental_due_cents=750,
            credit_balance_cents=10_000,
        )
    }

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(
            "app.services.payment_service.balance_summaries_for_users",
            lambda _session, ids: balances,
        )
        mp.setattr(
            "app.repositories.profile_repo.get_user_display_map",
            lambda _session, ids: {user_id: ("Alex Member", "alex@example.com")},
        )
        total, rows = pending_members_in_period(session, period, limit=10)

    assert total == 750
    assert len(rows) == 1
    assert rows[0].pending_cents == 750
    assert rows[0].full_name == "Alex Member"


def test_pending_members_total_matches_sum_of_rows() -> None:
    session = MagicMock()
    first = uuid.uuid4()
    second = uuid.uuid4()
    period = resolve_stats_period(period="all")

    session.scalars.return_value.all.return_value = [first, second]

    balances = {
        first: BalanceSummary(
            balance_due_cents=500,
            membership_due_cents=500,
            rental_due_cents=0,
            credit_balance_cents=0,
        ),
        second: BalanceSummary(
            balance_due_cents=250,
            membership_due_cents=0,
            rental_due_cents=250,
            credit_balance_cents=0,
        ),
    }

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(
            "app.services.payment_service.balance_summaries_for_users",
            lambda _session, ids: balances,
        )
        mp.setattr(
            "app.repositories.profile_repo.get_user_display_map",
            lambda _session, ids: {
                first: ("One", "one@example.com"),
                second: ("Two", "two@example.com"),
            },
        )
        total, rows = pending_members_in_period(session, period, limit=10)

    assert total == 750
    assert sum(row.pending_cents for row in rows) == total
