"""Auth introspection for Supabase-signed clients."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_principal
from app.db.session import get_db
from app.core.roles import parse_role
from app.repositories.profile_repo import apply_membership_choice, get_profile_by_id
from app.schemas.principal import MeOut, Principal

router = APIRouter()


def _me_from_principal(principal: Principal) -> MeOut:
    return MeOut(
        user_id=principal.id,
        email=principal.email,
        role=principal.role,
        full_name=principal.full_name,
        membership_tier=principal.membership_tier,
        volunteer_confirmed=principal.volunteer_confirmed,
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
    return MeOut(
        user_id=profile.id,
        email=principal.email,
        role=parse_role(profile.role),
        full_name=profile.full_name,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
    )
