"""Admin panel API models."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.booking import BookingOut


class AdminNotificationsOut(BaseModel):
    pending_volunteer_approvals: int = Field(
        ge=0,
        description="Duty-tier members waiting for volunteer approval.",
    )


class AdminMemberOut(BaseModel):
    user_id: str
    email: str = ""
    full_name: str = ""
    role: str
    membership_tier: str | None = None
    volunteer_confirmed: bool = False
    membership_started_at: datetime | None = Field(
        None,
        description="When the account was created (proxy for membership start).",
    )
    membership_ends_at: datetime | None = Field(
        None,
        description="Annual membership end (1 year after account creation).",
    )


class AdminMembersListResponse(BaseModel):
    data: list[AdminMemberOut]


class AdminBookingsListResponse(BaseModel):
    data: list[BookingOut]
