"""Load `profiles` rows linked to Supabase users."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.profile import Profile
from app.schemas.principal import KidProfile

_ALLOWED_TIERS = frozenset({"casual", "non_duty", "duty"})


def get_profile_by_id(session: Session, user_id: uuid.UUID) -> Profile | None:
    return session.scalar(select(Profile).where(Profile.id == user_id))


def kids_from_profile(profile: Profile) -> list[KidProfile]:
    """Read structured kids, falling back to legacy `kids_names`."""
    raw = profile.kids or []
    if raw:
        parsed: list[KidProfile] = []
        for item in raw:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or "").strip()
            if not name:
                continue
            birth_raw = item.get("birth_date")
            birth_date: date | None = None
            if birth_raw:
                try:
                    birth_date = date.fromisoformat(str(birth_raw))
                except ValueError:
                    birth_date = None
            parsed.append(KidProfile(name=name, birth_date=birth_date))
        return parsed
    return [KidProfile(name=name) for name in (profile.kids_names or []) if str(name).strip()]


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


def update_profile(
    session: Session,
    profile: Profile,
    *,
    full_name: str | None = None,
    kids: list[KidProfile] | None = None,
    avatar_path: str | None = None,
) -> Profile:
    """Update editable profile fields for the current user."""
    if full_name is not None:
        cleaned = full_name.strip()
        profile.full_name = cleaned or None
    if kids is not None:
        stored: list[dict[str, str | None]] = []
        names: list[str] = []
        for kid in kids:
            name = kid.name.strip()
            if not name:
                continue
            entry: dict[str, str | None] = {"name": name, "birth_date": None}
            if kid.birth_date is not None:
                entry["birth_date"] = kid.birth_date.isoformat()
            stored.append(entry)
            names.append(name)
        profile.kids = stored
        profile.kids_names = names
    if avatar_path is not None:
        cleaned_path = avatar_path.strip()
        profile.avatar_path = cleaned_path or None
    return profile


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
