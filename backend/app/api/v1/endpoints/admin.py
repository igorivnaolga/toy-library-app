"""Admin-only maintenance (MVP: approve duty-tier volunteers)."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin
from app.db.session import get_db
from app.repositories.profile_repo import (
    approve_duty_volunteer,
    get_profile_by_id,
    list_pending_duty_members,
)
from app.schemas.principal import Principal

router = APIRouter()


class PendingDutyVolunteerOut(BaseModel):
    user_id: str = Field(description="Supabase auth user id")
    email: str = ""
    full_name: str = ""


class PendingDutyVolunteersOut(BaseModel):
    data: list[PendingDutyVolunteerOut]


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
