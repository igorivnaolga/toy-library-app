"""Duty roster API request/response models."""

from __future__ import annotations

from datetime import date, datetime, time

from pydantic import BaseModel, Field, model_validator
from sqlalchemy.orm import Session

from app.models.duty_session import DutySession
from app.utils.text import visible_member_name


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


class DutySessionsListResponse(BaseModel):
    data: list[DutySessionOut]


class OnDutyResponse(BaseModel):
    on_duty: bool
    session: DutySessionOut | None = None


class DeskMemberOut(BaseModel):
    user_id: str
    full_name: str = ""
    email: str = ""


class DeskMembersResponse(BaseModel):
    data: list[DeskMemberOut]


def duty_session_out_from_model(row: DutySession, db: Session | None = None) -> DutySessionOut:
    volunteer_name = None
    volunteer_email = None
    if row.volunteer_id is not None:
        profile_name = None
        if row.volunteer is not None and row.volunteer.full_name:
            profile_name = row.volunteer.full_name.strip() or None
        if db is not None:
            from app.repositories.profile_repo import get_user_email

            volunteer_email = get_user_email(db, row.volunteer_id)
        volunteer_name = visible_member_name(profile_name, volunteer_email)
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
