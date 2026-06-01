"""Admin-only maintenance and panel data."""

from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin
from app.db.session import get_db
from app.repositories.profile_repo import (
    approve_duty_volunteer,
    count_pending_duty_members,
    get_profile_by_id,
    list_members_for_admin,
    list_pending_duty_members,
)
from app.schemas.admin import (
    AdminBookingsListResponse,
    AdminMemberOut,
    AdminMembersListResponse,
    AdminNotificationsOut,
)
from app.schemas.booking import booking_out_from_model
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


@router.get("/notifications", response_model=AdminNotificationsOut)
def admin_notifications(
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminNotificationsOut:
    return AdminNotificationsOut(
        pending_volunteer_approvals=count_pending_duty_members(db),
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
