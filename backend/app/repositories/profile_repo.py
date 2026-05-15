"""Load `profiles` rows linked to Supabase users."""

from __future__ import annotations

import uuid

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.profile import Profile

_ALLOWED_TIERS = frozenset({"casual", "non_duty", "duty"})


def get_profile_by_id(session: Session, user_id: uuid.UUID) -> Profile | None:
    return session.scalar(select(Profile).where(Profile.id == user_id))


def apply_membership_choice(session: Session, profile: Profile, tier: str) -> None:
    """Set first-time membership tier and promote to `member` (duty stays pending volunteer)."""
    if tier not in _ALLOWED_TIERS:
        raise ValueError("invalid_tier")
    if profile.membership_tier is not None and str(profile.membership_tier).strip() != "":
        raise ValueError("already_chosen")
    profile.membership_tier = tier
    profile.volunteer_confirmed = False
    if profile.role != "admin":
        profile.role = "member"


def approve_duty_volunteer(session: Session, profile: Profile) -> None:
    """Admin path: duty tier + pending → volunteer role."""
    if profile.membership_tier != "duty":
        raise ValueError("not_duty")
    profile.volunteer_confirmed = True
    profile.role = "volunteer"


def list_pending_duty_members(session: Session) -> list[dict[str, str]]:
    """Duty-tier users who are still `member` and not volunteer-confirmed (join `auth.users` for email)."""
    stmt = text(
        """
        select p.id::text as user_id,
               coalesce(u.email::text, '') as email,
               coalesce(p.full_name, '') as full_name
        from public.profiles p
        join auth.users u on u.id = p.id
        where p.membership_tier = 'duty'
          and coalesce(p.volunteer_confirmed, false) = false
          and p.role = 'member'
        order by u.created_at desc nulls last
        """
    )
    rows = session.execute(stmt).mappings().all()
    return [dict(r) for r in rows]
