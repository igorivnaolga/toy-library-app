"""Auth introspection for Supabase-signed clients."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_principal
from app.db.session import get_db
from app.core.roles import parse_role
from app.repositories.profile_repo import apply_membership_choice, get_profile_by_id, kids_from_profile, update_profile
from app.schemas.principal import MeOut, Principal, ProfileUpdateIn

router = APIRouter()


def _me_from_principal(principal: Principal) -> MeOut:
    return MeOut(
        user_id=principal.id,
        email=principal.email,
        role=principal.role,
        full_name=principal.full_name,
        membership_tier=principal.membership_tier,
        volunteer_confirmed=principal.volunteer_confirmed,
        kids=list(principal.kids),
        kids_names=list(principal.kids_names),
        avatar_path=principal.avatar_path,
    )


def _me_from_profile(profile, *, email: str | None) -> MeOut:
    kids = kids_from_profile(profile)
    return MeOut(
        user_id=profile.id,
        email=email,
        role=parse_role(profile.role),
        full_name=profile.full_name,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
        kids=kids,
        kids_names=[kid.name for kid in kids],
        avatar_path=profile.avatar_path,
    )


@router.get("/me", response_model=MeOut)
def read_me(principal: Principal = Depends(get_current_principal)) -> MeOut:
    """Return the current user id, email (from JWT), and **app role** from `profiles`."""
    return _me_from_principal(principal)


class MembershipChoiceIn(BaseModel):
    membership_tier: Literal["casual", "non_duty", "duty"]


@router.patch("/me/membership", response_model=MeOut)
def patch_my_membership(
    body: MembershipChoiceIn,
    principal: Principal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> MeOut:
    """First-time onboarding: set tier and promote to `member` (duty awaits admin volunteer approval)."""
    profile = get_profile_by_id(db, principal.id)
    if profile is None:
        raise HTTPException(status_code=403, detail="Profile not found")
    try:
        apply_membership_choice(db, profile, body.membership_tier)
    except ValueError as e:
        code = str(e)
        if code == "already_chosen":
            raise HTTPException(
                status_code=409,
                detail="Membership tier is already set for this account.",
            ) from e
        raise HTTPException(status_code=400, detail="Invalid membership choice.") from e
    db.commit()
    db.refresh(profile)
    return _me_from_profile(profile, email=principal.email)


@router.patch("/me/profile", response_model=MeOut)
def patch_my_profile(
    body: ProfileUpdateIn,
    principal: Principal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> MeOut:
    """Update editable profile fields for the current user."""
    profile = get_profile_by_id(db, principal.id)
    if profile is None:
        raise HTTPException(status_code=403, detail="Profile not found")
    update_profile(
        db,
        profile,
        full_name=body.full_name,
        kids=body.kids,
        avatar_path=body.avatar_path,
    )
    db.commit()
    db.refresh(profile)
    return _me_from_profile(profile, email=principal.email)
