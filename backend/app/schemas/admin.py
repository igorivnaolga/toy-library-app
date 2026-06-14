"""Admin panel API models."""

from __future__ import annotations

from datetime import date, datetime

from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.booking import BookingOut
from app.schemas.loan import LoanOut
from app.schemas.principal import KidProfile, ProfileContactOut


class AdminNotificationsOut(BaseModel):
    pending_volunteer_approvals: int = Field(
        ge=0,
        description="Duty-tier members waiting for volunteer approval.",
    )
    pending_duty_confirmations: int = Field(
        ge=0,
        description="Today's booked duty shifts waiting for admin confirmation.",
    )
    new_members_count: int = Field(
        ge=0,
        description="Members who joined in the last 30 days (excludes pending duty approvals).",
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
    duty_sessions_completed: int = Field(
        0,
        ge=0,
        description="Past booked volunteer duty shifts (for duty-tier members).",
    )


class AdminMembersListResponse(BaseModel):
    data: list[AdminMemberOut]


class AdminMemberDetailOut(AdminMemberOut, ProfileContactOut):
    kids: list[KidProfile] = Field(default_factory=list)
    avatar_path: str | None = None
    admin_notes: str | None = Field(
        None,
        description="Private notes visible to admins only.",
    )
    membership_due_cents: int = Field(
        0,
        ge=0,
        description="Pending membership and bond charges (NZD cents).",
    )
    membership_fees_paid: bool = True
    balance_due_cents: int = Field(
        0,
        ge=0,
        description="Total pending balance in NZD cents.",
    )
    credit_balance_cents: int = Field(
        0,
        ge=0,
        description="Unapplied account credit from top-ups (NZD cents).",
    )
    loans: list[LoanOut] = Field(
        default_factory=list,
        description="Member loan history (newest checkouts first).",
    )


class AdminMembershipUpdateIn(BaseModel):
    membership_tier: Literal["casual", "non_duty", "duty"]


class AdminMemberUpdateIn(BaseModel):
    kids: list[KidProfile] | None = None
    admin_notes: str | None = None


class AdminBookingsListResponse(BaseModel):
    data: list[BookingOut]
