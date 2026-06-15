"""Duty roster API request/response models."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time

from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from app.models.duty_session import DutySession


class DutySessionCreate(BaseModel):
    session_date: date
    start_time: time
    end_time: time
    volunteer_id: str | None = Field(
        default=None,
        description="Optional volunteer assigned by admin; omit for an open slot.",
    )

    @model_validator(mode="after")
    def end_after_start(self) -> DutySessionCreate:
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time.")
        return self


class DutySessionAssign(BaseModel):
    user_id: str = Field(min_length=1, description="Member or volunteer profile id.")


class DutySessionOut(BaseModel):
    session_id: str
    session_date: date
    start_time: time
    end_time: time
    volunteer_id: str | None = None
    volunteer_name: str | None = None
    volunteer_email: str | None = None
    admin_confirmed: bool = False
    admin_confirmed_at: datetime | None = None
    created_at: datetime


class DutyBookResponse(BaseModel):
    session: DutySessionOut
    volunteer_booked_count: int = Field(
        0,
        ge=0,
        description="Total duty slots this volunteer has booked (past and upcoming).",
    )
    booking_milestone_message: str | None = Field(
        None,
        description="Optional thank-you message at booking milestones (e.g. third shift).",
    )


class DutySessionsListResponse(BaseModel):
    data: list[DutySessionOut]


class VolunteerDutyProfileOut(BaseModel):
    upcoming: list[DutySessionOut] = Field(default_factory=list)
    completed: list[DutySessionOut] = Field(default_factory=list)


class OnDutyResponse(BaseModel):
    on_duty: bool
    session: DutySessionOut | None = None


class DeskMemberOut(BaseModel):
    user_id: str
    full_name: str = ""
    email: str = ""
    balance_due_cents: int = Field(
        0,
        ge=0,
        description="Member's total pending balance at checkout.",
    )
    credit_balance_cents: int = Field(
        0,
        ge=0,
        description="Member unapplied account credit at checkout.",
    )


class DeskMembersResponse(BaseModel):
    data: list[DeskMemberOut]


def _volunteer_ids(rows: list[DutySession]) -> set[uuid.UUID]:
    return {row.volunteer_id for row in rows if row.volunteer_id is not None}


def duty_sessions_out_from_models(
    rows: list[DutySession],
    db: Session | None = None,
) -> list[DutySessionOut]:
    """Build duty session responses with batched profile name/email lookup."""
    display_map: dict[uuid.UUID, tuple[str, str]] = {}
    if db is not None:
        from app.repositories.profile_repo import get_user_display_map

        display_map = get_user_display_map(db, _volunteer_ids(rows))
    return [
        duty_session_out_from_model(row, db, display_map=display_map)
        for row in rows
    ]


def duty_session_out_from_model(
    row: DutySession,
    db: Session | None = None,
    *,
    display_map: dict[uuid.UUID, tuple[str, str]] | None = None,
) -> DutySessionOut:
    volunteer_name = None
    volunteer_email = None
    if row.volunteer_id is not None:
        full_name = ""
        email = ""
        if display_map is not None:
            full_name, email = display_map.get(row.volunteer_id, ("", ""))
        elif db is not None:
            from app.repositories.profile_repo import get_user_display_map

            full_name, email = get_user_display_map(db, {row.volunteer_id}).get(
                row.volunteer_id,
                ("", ""),
            )
        elif row.volunteer is not None and row.volunteer.full_name:
            full_name = row.volunteer.full_name

        cleaned_name = (full_name or "").strip()
        volunteer_name = cleaned_name or None
        cleaned_email = (email or "").strip()
        volunteer_email = cleaned_email or None
    return DutySessionOut(
        session_id=str(row.id),
        session_date=row.session_date,
        start_time=row.start_time,
        end_time=row.end_time,
        volunteer_id=str(row.volunteer_id) if row.volunteer_id else None,
        volunteer_name=volunteer_name,
        volunteer_email=volunteer_email,
        admin_confirmed=row.admin_confirmed_at is not None,
        admin_confirmed_at=row.admin_confirmed_at,
        created_at=row.created_at,
    )
