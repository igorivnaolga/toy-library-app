"""Application roles stored in `profiles.role` (see Supabase auth + `profiles` table)."""

from enum import Enum


class Role(str, Enum):
    """Higher-privilege roles inherit capabilities in guards via `require_roles` (+ admin bypass)."""

    GUEST = "guest"
    MEMBER = "member"
    VOLUNTEER = "volunteer"
    ADMIN = "admin"


def parse_role(value: str | None) -> Role:
    if not value:
        return Role.GUEST
    try:
        return Role(value.strip().lower())
    except ValueError:
        return Role.GUEST
