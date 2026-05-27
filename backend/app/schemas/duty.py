"""Duty roster API request/response models."""

from __future__ import annotations

from datetime import date, datetime, time

from pydantic import BaseModel, Field, model_validator

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


class DutySessionOut(BaseModel):
    session_id: str
    session_date: date
    start_time: time
    end_time: time
    volunteer_id: str | None = None
    volunteer_name: str | None = None
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


def duty_session_out_from_model(row: DutySession) -> DutySessionOut:
    volunteer_name = None
    if row.volunteer is not None and row.volunteer.full_name:
        volunteer_name = row.volunteer.full_name
    return DutySessionOut(
        session_id=str(row.id),
        session_date=row.session_date,
        start_time=row.start_time,
        end_time=row.end_time,
        volunteer_id=str(row.volunteer_id) if row.volunteer_id else None,
        volunteer_name=volunteer_name,
        created_at=row.created_at,
    )
