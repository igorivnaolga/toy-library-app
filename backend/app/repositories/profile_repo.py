"""Load `profiles` rows linked to Supabase users."""

from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models.profile import Profile
from app.schemas.principal import KidProfile

_ALLOWED_TIERS = frozenset({"casual", "non_duty", "duty"})
RECENT_MEMBERS_DAYS = 30


def get_profile_by_id(session: Session, user_id: uuid.UUID) -> Profile | None:
    return session.scalar(select(Profile).where(Profile.id == user_id))


def get_user_email(session: Session, user_id: uuid.UUID) -> str | None:
    row = session.execute(
        text("select email::text from auth.users where id = :id"),
        {"id": user_id},
    ).scalar_one_or_none()
    if row is None:
        return None
    email = str(row).strip()
    return email or None


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


def _recent_members_sql_extra() -> str:
    """Members with a chosen tier in the last month (duty-pending listed separately)."""
    return f"""
          and p.membership_tier is not null
          and p.role in ('member', 'volunteer')
          and u.created_at >= (now() at time zone 'utc') - make_interval(days => :days)
          and not (
            p.membership_tier = 'duty'
            and coalesce(p.volunteer_confirmed, false) = false
            and p.role = 'member'
          )
    """


def count_recent_members(session: Session, *, days: int = RECENT_MEMBERS_DAYS) -> int:
    stmt = text(
        f"""
        select count(*)::int
        from public.profiles p
        join auth.users u on u.id = p.id
        where true
        {_recent_members_sql_extra()}
        """
    )
    return int(session.execute(stmt, {"days": days}).scalar_one() or 0)


def list_recent_members_for_admin(
    session: Session,
    *,
    days: int = RECENT_MEMBERS_DAYS,
    limit: int = 50,
) -> list[dict[str, str | bool | None]]:
    stmt = text(
        f"""
        select p.id::text as user_id,
               coalesce(u.email::text, '') as email,
               coalesce(p.full_name, '') as full_name,
               p.role,
               p.membership_tier,
               coalesce(p.volunteer_confirmed, false) as volunteer_confirmed,
               u.created_at as membership_started_at,
               (u.created_at + interval '1 year') as membership_ends_at
        from public.profiles p
        join auth.users u on u.id = p.id
        where true
        {_recent_members_sql_extra()}
        order by u.created_at desc nulls last
        limit :limit
        """
    )
    rows = session.execute(stmt, {"days": days, "limit": limit}).mappings().all()
    return [dict(r) for r in rows]


def count_pending_duty_members(session: Session) -> int:
    stmt = text(
        """
        select count(*)::int
        from public.profiles p
        where p.membership_tier = 'duty'
          and coalesce(p.volunteer_confirmed, false) = false
          and p.role = 'member'
        """
    )
    return int(session.execute(stmt).scalar_one() or 0)


def list_members_for_admin(
    session: Session,
    *,
    membership_tier: str | None = None,
    started_from: date | None = None,
    started_to: date | None = None,
    ending_from: date | None = None,
    ending_to: date | None = None,
    q: str | None = None,
    limit: int = 200,
) -> list[dict[str, str | bool | None]]:
    """Members/volunteers for admin panel with optional filters."""
    filters = ["p.role in ('member', 'volunteer')"]
    params: dict[str, object] = {"limit": limit}

    if membership_tier:
        filters.append("p.membership_tier = :membership_tier")
        params["membership_tier"] = membership_tier.strip()

    if started_from is not None:
        filters.append("u.created_at::date >= :started_from")
        params["started_from"] = started_from

    if started_to is not None:
        filters.append("u.created_at::date <= :started_to")
        params["started_to"] = started_to

    if ending_from is not None:
        filters.append("(u.created_at + interval '1 year')::date >= :ending_from")
        params["ending_from"] = ending_from

    if ending_to is not None:
        filters.append("(u.created_at + interval '1 year')::date <= :ending_to")
        params["ending_to"] = ending_to

    if q:
        pattern = f"%{q.strip()}%"
        filters.append(
            """(
              coalesce(p.full_name, '') ilike :pattern
              or coalesce(u.email::text, '') ilike :pattern
              or p.id::text ilike :pattern
            )"""
        )
        params["pattern"] = pattern

    where_clause = " and ".join(filters)
    stmt = text(
        f"""
        select p.id::text as user_id,
               coalesce(u.email::text, '') as email,
               coalesce(p.full_name, '') as full_name,
               p.role,
               p.membership_tier,
               coalesce(p.volunteer_confirmed, false) as volunteer_confirmed,
               u.created_at as membership_started_at,
               (u.created_at + interval '1 year') as membership_ends_at
        from public.profiles p
        join auth.users u on u.id = p.id
        where {where_clause}
        order by u.created_at desc nulls last
        limit :limit
        """
    )
    rows = session.execute(stmt, params).mappings().all()
    return [dict(r) for r in rows]


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


def list_roster_members(session: Session, *, limit: int = 30) -> list[dict[str, str]]:
    """Recent members/volunteers for duty roster assignment picker."""
    stmt = text(
        """
        select p.id::text as user_id,
               coalesce(p.full_name, '') as full_name,
               coalesce(u.email::text, '') as email
        from public.profiles p
        join auth.users u on u.id = p.id
        where p.role in ('member', 'volunteer', 'admin')
        order by p.full_name nulls last, u.email
        limit :limit
        """
    )
    rows = session.execute(stmt, {"limit": limit}).mappings().all()
    return [dict(r) for r in rows]


def search_members_for_desk(
    session: Session,
    query: str,
    *,
    limit: int = 20,
) -> list[dict[str, str]]:
    """Find members/volunteers by name, email, or profile id (volunteer desk walk-in)."""
    cleaned = query.strip()
    if len(cleaned) < 2:
        return []
    pattern = f"%{cleaned}%"
    stmt = text(
        """
        select p.id::text as user_id,
               coalesce(p.full_name, '') as full_name,
               coalesce(u.email::text, '') as email
        from public.profiles p
        join auth.users u on u.id = p.id
        where p.role in ('member', 'volunteer', 'admin')
          and (
            coalesce(p.full_name, '') ilike :pattern
            or coalesce(u.email::text, '') ilike :pattern
            or p.id::text ilike :pattern
          )
        order by p.full_name nulls last, u.email
        limit :limit
        """
    )
    rows = session.execute(
        stmt,
        {"pattern": pattern, "limit": limit},
    ).mappings().all()
    return [dict(r) for r in rows]
