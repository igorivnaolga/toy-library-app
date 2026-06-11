"""Membership fee amounts (NZD cents) — keep in sync with mobile library copy."""

from __future__ import annotations

MEMBERSHIP_FEE_CENTS: dict[str, int] = {
    "duty": 6_500,
    "non_duty": 15_000,
    "casual": 5_000,
}

CASUAL_BOND_CENTS = 5_000

_MEMBERSHIP_LABELS = {
    "duty": "Duty membership",
    "non_duty": "Non-duty membership",
    "casual": "Casual membership",
}


def charges_for_tier(tier: str) -> list[tuple[str, int, str]]:
    """Return (payment_type, amount_cents, description) rows for a new tier."""
    fee = MEMBERSHIP_FEE_CENTS.get(tier)
    if fee is None:
        raise ValueError("invalid_tier")
    label = _MEMBERSHIP_LABELS[tier]
    rows: list[tuple[str, int, str]] = [("membership", fee, label)]
    if tier == "casual":
        rows.append(("bond", CASUAL_BOND_CENTS, "Casual refundable bond"))
    return rows
