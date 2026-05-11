"""
Canonical toy *lending* availability for API responses.

`ToyOut.status` keeps the raw label from CSV/DB (e.g. "In library", "On loan").
`ToyOut.availability` is a small stable code for clients and filters.

Known CSV `Status` values (export_imgs/toy_photo_map_by_description.csv):
- In library → available
- On loan, On loan (overdue) → on_loan
- Being repaired, Missing, Joined with another toy → unavailable
- reserved is reserved for future booking/hold flows when not in CSV.
"""

from __future__ import annotations

# Stable codes exposed in JSON and used for filtering later.
AVAILABLE = "available"
ON_LOAN = "on_loan"
RESERVED = "reserved"
UNAVAILABLE = "unavailable"
UNKNOWN = "unknown"
VALID_AVAILABILITY_CODES = frozenset(
    {AVAILABLE, ON_LOAN, RESERVED, UNAVAILABLE, UNKNOWN}
)


def normalize_availability(raw_status: str | None) -> str:
    """
    Map a free-text inventory/status label to a canonical availability code.

    Unknown or empty input returns ``unknown`` so the UI can still render safely.
    """
    if not raw_status:
        return UNKNOWN

    key = raw_status.strip().lower()
    if not key:
        return UNKNOWN

    if key in VALID_AVAILABILITY_CODES:
        return key

    # Exact-ish phrases from seed CSV (order: more specific first).
    if "overdue" in key or key == "on loan" or key.startswith("on loan"):
        return ON_LOAN
    if "in library" in key or key == "available":
        return AVAILABLE
    if "repair" in key or "missing" in key or "joined" in key:
        return UNAVAILABLE
    if "reserved" in key or "hold" in key:
        return RESERVED

    # Single-token fallbacks
    if key in {"loan", "borrowed", "checked_out", "checked out"}:
        return ON_LOAN

    return UNKNOWN
