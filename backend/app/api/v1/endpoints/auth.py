"""Auth introspection for Supabase-signed clients."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_principal
from app.db.session import get_db
from app.core.roles import parse_role
from app.repositories.profile_repo import (
    apply_membership_choice,
    complete_registration,
    get_profile_by_id,
    kids_from_profile,
    update_profile,
)
from app.schemas.principal import MeOut, Principal, ProfileUpdateIn, RegistrationCompleteIn
from app.services.payment_service import (
    balance_summary,
    create_membership_payments_for_tier,
    membership_payment_summary,
    refresh_membership_payments_for_tier,
)

router = APIRouter()


def _contact_fields_from_profile(profile) -> dict:
    return {
        "parent_b_name": profile.parent_b_name,
        "address_line1": profile.address_line1,
        "address_line2": profile.address_line2,
        "suburb": profile.suburb,
        "mobile_phone": profile.mobile_phone,
        "alt_contact_name": profile.alt_contact_name,
        "alt_contact_address": profile.alt_contact_address,
        "alt_contact_phone": profile.alt_contact_phone,
        "heard_about_us": profile.heard_about_us,
        "skills": profile.skills,
        "text_reminders_consent": profile.text_reminders_consent,
        "terms_accepted_at": profile.terms_accepted_at,
        "registered_at": profile.registered_at,
    }


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


def _me_from_profile(profile, *, email: str | None, db: Session | None = None) -> MeOut:
    kids = kids_from_profile(profile)
    payment_summary = None
    account_balance = None
    if db is not None:
        payment_summary = membership_payment_summary(db, profile.id)
        account_balance = balance_summary(db, profile.id)
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
        membership_due_cents=payment_summary.due_cents if payment_summary else 0,
        membership_fees_paid=payment_summary.fees_paid if payment_summary else True,
        balance_due_cents=account_balance.balance_due_cents if account_balance else 0,
        credit_balance_cents=account_balance.credit_balance_cents if account_balance else 0,
        **_contact_fields_from_profile(profile),
    )


@router.get("/me", response_model=MeOut)
def read_me(
    principal: Principal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> MeOut:
    """Return the current user id, email (from JWT), and profile details."""
    profile = get_profile_by_id(db, principal.id)
    if profile is None:
        raise HTTPException(status_code=403, detail="Profile not found")
    return _me_from_profile(profile, email=principal.email, db=db)


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
        create_membership_payments_for_tier(db, profile.id, body.membership_tier)
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
    return _me_from_profile(profile, email=principal.email, db=db)


@router.post("/me/registration", response_model=MeOut)
def complete_my_registration(
    body: RegistrationCompleteIn,
    principal: Principal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> MeOut:
    """Submit the library membership form after account creation."""
    profile = get_profile_by_id(db, principal.id)
    if profile is None:
        raise HTTPException(status_code=403, detail="Profile not found")
    if profile.terms_accepted_at is not None:
        raise HTTPException(
            status_code=409,
            detail="Registration form has already been submitted.",
        )
    try:
        complete_registration(
            db,
            profile,
            full_name=body.full_name,
            parent_b_name=body.parent_b_name,
            address_line1=body.address_line1,
            address_line2=body.address_line2,
            suburb=body.suburb,
            mobile_phone=body.mobile_phone,
            alt_contact_name=body.alt_contact_name,
            alt_contact_address=body.alt_contact_address,
            alt_contact_phone=body.alt_contact_phone,
            heard_about_us=body.heard_about_us,
            skills=body.skills,
            kids=body.kids,
            membership_tier=body.membership_tier,
            text_reminders_consent=body.text_reminders_consent,
            registered_at=body.registered_at,
        )
        create_membership_payments_for_tier(db, profile.id, body.membership_tier)
    except ValueError as e:
        code = str(e)
        if code == "already_chosen":
            raise HTTPException(
                status_code=409,
                detail="Membership tier is already set for this account.",
            ) from e
        raise HTTPException(status_code=400, detail="Invalid registration data.") from e
    db.commit()
    db.refresh(profile)
    return _me_from_profile(profile, email=principal.email, db=db)


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
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    update_profile(
        db,
        profile,
        kids=body.kids,
        avatar_path=body.avatar_path,
        parent_b_name=body.parent_b_name,
        address_line1=body.address_line1,
        address_line2=body.address_line2,
        suburb=body.suburb,
        mobile_phone=body.mobile_phone,
        alt_contact_name=body.alt_contact_name,
        alt_contact_address=body.alt_contact_address,
        alt_contact_phone=body.alt_contact_phone,
        heard_about_us=body.heard_about_us,
        skills=body.skills,
        text_reminders_consent=body.text_reminders_consent,
        registered_at=body.registered_at,
        parent_b_name_set="parent_b_name" in payload,
        address_line1_set="address_line1" in payload,
        address_line2_set="address_line2" in payload,
        suburb_set="suburb" in payload,
        mobile_phone_set="mobile_phone" in payload,
        alt_contact_name_set="alt_contact_name" in payload,
        alt_contact_address_set="alt_contact_address" in payload,
        alt_contact_phone_set="alt_contact_phone" in payload,
        heard_about_us_set="heard_about_us" in payload,
        skills_set="skills" in payload,
        text_reminders_consent_set="text_reminders_consent" in payload,
        registered_at_set="registered_at" in payload,
    )
    db.commit()
    db.refresh(profile)
    return _me_from_profile(profile, email=principal.email, db=db)
