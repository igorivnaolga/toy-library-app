"""Admin-only maintenance and panel data."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin
from app.db.session import get_db
from app.repositories.duty_repo import list_todays_unconfirmed_duty_sessions
from app.repositories.profile_repo import (
    RECENT_MEMBERS_DAYS,
    approve_duty_volunteer,
    count_pending_duty_members,
    count_recent_members,
    get_profile_by_id,
    get_user_email,
    kids_from_profile,
    list_members_for_admin,
    list_pending_duty_members,
    list_recent_members_for_admin,
    update_member_for_admin,
    update_membership_tier_for_admin,
)
from app.schemas.admin import (
    AdminBookingsListResponse,
    AdminMemberDetailOut,
    AdminMemberOut,
    AdminMembersListResponse,
    AdminMembershipUpdateIn,
    AdminMemberUpdateIn,
    AdminNotificationsOut,
)
from app.schemas.booking import booking_out_from_model
from app.schemas.duty import DutySessionOut, duty_session_out_from_model
from app.schemas.principal import Principal
from app.schemas.toy import ToyOut, ToyUpdate
from app.services.booking_service import list_bookings_for_admin_service
from app.services.toy_service import update_toy_service

router = APIRouter()


class PendingDutyVolunteerOut(BaseModel):
    user_id: str = Field(description="Supabase auth user id")
    email: str = ""
    full_name: str = ""


class PendingDutyVolunteersOut(BaseModel):
    data: list[PendingDutyVolunteerOut]


class TodaysDutyShiftsOut(BaseModel):
    data: list[DutySessionOut]


@router.get("/notifications", response_model=AdminNotificationsOut)
def admin_notifications(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminNotificationsOut:
    return AdminNotificationsOut(
        pending_volunteer_approvals=count_pending_duty_members(db),
        pending_duty_confirmations=0,
        new_members_count=count_recent_members(db),
    )


@router.get("/todays-duty-shifts", response_model=TodaysDutyShiftsOut)
def todays_duty_shifts(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> TodaysDutyShiftsOut:
    """Booked duty shifts today that still need admin confirmation."""
    rows = list_todays_unconfirmed_duty_sessions(db)
    return TodaysDutyShiftsOut(
        data=[duty_session_out_from_model(row, db) for row in rows],
    )


@router.get("/recent-members", response_model=AdminMembersListResponse)
def recent_members(
    days: int = Query(
        RECENT_MEMBERS_DAYS,
        ge=1,
        le=90,
        description="Include members whose account was created within this many days.",
    ),
    limit: int = Query(50, ge=1, le=200),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMembersListResponse:
    rows = list_recent_members_for_admin(db, days=days, limit=limit)
    return AdminMembersListResponse(
        data=[AdminMemberOut.model_validate(row) for row in rows],
    )


@router.get("/pending-duty-volunteers", response_model=PendingDutyVolunteersOut)
def pending_duty_volunteers(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PendingDutyVolunteersOut:
    rows = list_pending_duty_members(db)
    return PendingDutyVolunteersOut(
        data=[PendingDutyVolunteerOut.model_validate(r) for r in rows],
    )


@router.post("/users/{user_id}/approve-volunteer")
def approve_volunteer(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> dict[str, str | bool]:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.membership_tier != "duty":
        raise HTTPException(
            status_code=400,
            detail="User is not on duty tier; nothing to approve as volunteer.",
        )
    if profile.volunteer_confirmed and profile.role == "volunteer":
        return {"ok": True, "user_id": str(user_id), "already_approved": True}
    try:
        approve_duty_volunteer(db, profile)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    db.commit()
    return {"ok": True, "user_id": str(user_id), "already_approved": False}


@router.get("/bookings", response_model=AdminBookingsListResponse)
def list_all_bookings(
    pickup_from: date | None = Query(None, description="Earliest pickup day."),
    pickup_to: date | None = Query(None, description="Latest pickup day."),
    user_id: uuid.UUID | None = Query(None, description="Filter by member profile id."),
    q: str | None = Query(None, description="Search toy, member name, or email."),
    limit: int = Query(200, ge=1, le=500),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminBookingsListResponse:
    rows = list_bookings_for_admin_service(
        db,
        pickup_from=pickup_from,
        pickup_to=pickup_to,
        user_id=user_id,
        q=q,
        limit=limit,
    )
    return AdminBookingsListResponse(
        data=[
            booking_out_from_model(booking, member_email=email)
            for booking, email in rows
        ],
    )


@router.get("/members", response_model=AdminMembersListResponse)
def list_members(
    membership_tier: str | None = Query(
        None,
        description="casual | non_duty | duty",
    ),
    started_from: date | None = Query(None, description="Membership started on/after."),
    started_to: date | None = Query(None, description="Membership started on/before."),
    ending_from: date | None = Query(None, description="Membership ends on/after."),
    ending_to: date | None = Query(None, description="Membership ends on/before."),
    q: str | None = Query(None, description="Search name, email, or profile id."),
    limit: int = Query(200, ge=1, le=500),
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMembersListResponse:
    rows = list_members_for_admin(
        db,
        membership_tier=membership_tier,
        started_from=started_from,
        started_to=started_to,
        ending_from=ending_from,
        ending_to=ending_to,
        q=q,
        limit=limit,
    )
    return AdminMembersListResponse(
        data=[AdminMemberOut.model_validate(row) for row in rows],
    )


def _member_detail_out(session: Session, profile) -> AdminMemberDetailOut:
    created_row = session.execute(
        text("select created_at from auth.users where id = :id"),
        {"id": profile.id},
    ).scalar_one_or_none()
    membership_started_at = created_row
    membership_ends_at = None
    if created_row is not None:
        membership_ends_at = created_row + timedelta(days=365)
    kids = kids_from_profile(profile)
    return AdminMemberDetailOut(
        user_id=str(profile.id),
        email=get_user_email(session, profile.id) or "",
        full_name=profile.full_name or "",
        role=profile.role,
        membership_tier=profile.membership_tier,
        volunteer_confirmed=bool(profile.volunteer_confirmed),
        membership_started_at=membership_started_at,
        membership_ends_at=membership_ends_at,
        kids=kids,
        avatar_path=profile.avatar_path,
        admin_notes=profile.admin_notes,
    )


@router.get("/users/{user_id}", response_model=AdminMemberDetailOut)
def get_member_detail(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    return _member_detail_out(db, profile)


@router.patch("/users/{user_id}/membership", response_model=AdminMemberDetailOut)
def update_member_membership(
    user_id: uuid.UUID,
    body: AdminMembershipUpdateIn,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    try:
        update_membership_tier_for_admin(db, profile, body.membership_tier)
    except ValueError as e:
        code = str(e)
        if code == "cannot_change_admin":
            raise HTTPException(
                status_code=400,
                detail="Cannot change membership for admin accounts.",
            ) from e
        raise HTTPException(status_code=400, detail="Invalid membership tier.") from e
    db.commit()
    db.refresh(profile)
    return _member_detail_out(db, profile)


@router.patch("/users/{user_id}", response_model=AdminMemberDetailOut)
def update_member_profile(
    user_id: uuid.UUID,
    body: AdminMemberUpdateIn,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminMemberDetailOut:
    profile = get_profile_by_id(db, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    if profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    update_member_for_admin(
        db,
        profile,
        kids=body.kids,
        admin_notes=body.admin_notes,
        admin_notes_set="admin_notes" in payload,
    )
    db.commit()
    db.refresh(profile)
    return _member_detail_out(db, profile)


@router.patch("/toys/{toy_id}", response_model=ToyOut)
def update_toy(
    toy_id: str,
    body: ToyUpdate,
    _: Principal = Depends(require_admin),
) -> ToyOut:
    """Edit catalog metadata for a toy (requires DB-backed catalog)."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    updated = update_toy_service(
        toy_id,
        name=payload.get("name"),
        category=payload.get("category"),
        age_range=payload.get("age_range"),
        status=payload.get("status"),
        manufacturer=payload.get("manufacturer"),
        description=payload.get("description"),
        total_pieces=payload.get("total_pieces"),
        missing_pieces=payload.get("missing_pieces"),
    )
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return updated
