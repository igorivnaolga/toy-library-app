"""
FastAPI dependencies for Supabase JWT + `profiles.role`.

- **Guest (anonymous):** no `Authorization` header — use optional dependency where catalog stays public.
- **Logged-in users:** `Authorization: Bearer <supabase_access_token>` — JWT verified, then role loaded from `public.profiles`.
- **Admin** bypasses role-set checks in `require_roles` (full access).
"""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.roles import Role, parse_role
from app.core.supabase_jwt import decode_supabase_access_token
from app.db.session import get_db
from app.repositories.duty_repo import is_volunteer_on_duty_now
from app.repositories.profile_repo import get_profile_by_id, kids_from_profile
from app.schemas.principal import Principal

bearer_scheme = HTTPBearer(auto_error=False)


def _parse_uuid_sub(sub: str | None) -> uuid.UUID:
    if not sub:
        raise HTTPException(status_code=401, detail="Token missing subject")
    try:
        return uuid.UUID(sub)
    except ValueError as e:
        raise HTTPException(status_code=401, detail="Invalid subject") from e


def get_current_principal(
    db: Annotated[Session, Depends(get_db)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> Principal:
    """Requires a valid Bearer token + existing `profiles` row."""
    if credentials is None or not credentials.credentials:
        raise HTTPException(status_code=401, detail="Not authenticated")
    settings = get_settings()
    payload = decode_supabase_access_token(credentials.credentials.strip(), settings)
    user_id = _parse_uuid_sub(payload.get("sub"))
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(
            status_code=403,
            detail="Profile not found for this user. Run Supabase SQL to create `profiles` + signup trigger.",
        )
    role = parse_role(profile.role)
    kids = kids_from_profile(profile)
    return Principal(
        id=user_id,
        email=payload.get("email"),
        role=role,
        full_name=profile.full_name,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
        kids=kids,
        kids_names=[kid.name for kid in kids],
        avatar_path=profile.avatar_path,
    )


def get_optional_principal(
    db: Annotated[Session, Depends(get_db)],
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> Principal | None:
    """Returns `Principal` when Authorization is valid; otherwise `None` (guest browsing)."""
    if credentials is None or not credentials.credentials:
        return None
    settings = get_settings()
    payload = decode_supabase_access_token(credentials.credentials.strip(), settings)
    user_id = _parse_uuid_sub(payload.get("sub"))
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        return None
    role = parse_role(profile.role)
    kids = kids_from_profile(profile)
    return Principal(
        id=user_id,
        email=payload.get("email"),
        role=role,
        full_name=profile.full_name,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
        kids=kids,
        kids_names=[kid.name for kid in kids],
        avatar_path=profile.avatar_path,
    )


def require_roles(*allowed: Role):
    """
    Dependency factory: caller must have one of `allowed` roles, **or** be `admin`.

    Example (volunteer check-in/out later):

        @router.post("/loans/check-out")
        def check_out(..., principal: Principal = Depends(require_roles(Role.VOLUNTEER))):
            ...
    """

    allowed_set = set(allowed)

    def _guard(principal: Principal = Depends(get_current_principal)) -> Principal:
        if principal.role == Role.ADMIN:
            return principal
        if principal.role not in allowed_set:
            raise HTTPException(status_code=403, detail="Insufficient role")
        return principal

    return _guard


def require_admin(
    principal: Annotated[Principal, Depends(get_current_principal)],
) -> Principal:
    """Allow only `profiles.role = admin` (no bypass for other roles)."""
    if principal.role != Role.ADMIN:
        raise HTTPException(status_code=403, detail="Admin only")
    return principal


def require_on_duty_desk():
    """
    Volunteer desk actions: volunteer must have a booked duty slot covering now.
    Admin bypasses the on-duty check.
    """

    _require_volunteer = require_roles(Role.VOLUNTEER, Role.ADMIN)

    def _guard(
        db: Annotated[Session, Depends(get_db)],
        principal: Principal = Depends(_require_volunteer),
    ) -> Principal:
        if principal.role == Role.ADMIN:
            return principal
        if not is_volunteer_on_duty_now(db, principal.id):
            raise HTTPException(
                status_code=403,
                detail="You must be on duty to use the volunteer desk.",
            )
        return principal

    return _guard
