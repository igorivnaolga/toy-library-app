"""Pydantic models for library events."""

from __future__ import annotations

from datetime import date, datetime, time
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


EventAudience = Literal["volunteer", "member"]


class EventSlotCreateIn(BaseModel):
    start_time: time
    end_time: time
    capacity: int = Field(ge=1, le=500)
    audience: EventAudience

    @field_validator("end_time")
    @classmethod
    def _end_after_start(cls, end_time: time, info) -> time:
        start = info.data.get("start_time")
        if start is not None and end_time <= start:
            raise ValueError("End time must be after start time.")
        return end_time


class EventCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    event_date: date
    end_date: date | None = None
    is_published: bool = True
    slots: list[EventSlotCreateIn] = Field(min_length=1)

    @model_validator(mode="after")
    def _normalize_dates(self) -> EventCreateIn:
        if self.end_date is None:
            self.end_date = self.event_date
        elif self.end_date < self.event_date:
            raise ValueError("End date must be on or after start date.")
        return self


class EventUpdateIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=5000)
    event_date: date | None = None
    end_date: date | None = None
    is_published: bool | None = None
    slots: list[EventSlotCreateIn] | None = None

    @model_validator(mode="after")
    def _validate_dates(self) -> EventUpdateIn:
        if (
            self.event_date is not None
            and self.end_date is not None
            and self.end_date < self.event_date
        ):
            raise ValueError("End date must be on or after start date.")
        return self


class EventBookingUserOut(BaseModel):
    user_id: str
    full_name: str = ""
    email: str = ""


class EventSlotOut(BaseModel):
    slot_id: str
    start_time: str
    end_time: str
    capacity: int
    audience: EventAudience
    booked_count: int = Field(ge=0)
    spots_left: int = Field(ge=0)
    is_full: bool
    user_booked: bool = False
    bookings: list[EventBookingUserOut] = Field(default_factory=list)


class EventOut(BaseModel):
    event_id: str
    name: str
    description: str | None = None
    event_date: date
    end_date: date
    is_published: bool
    created_at: datetime
    slots: list[EventSlotOut] = Field(default_factory=list)


class EventsListResponse(BaseModel):
    data: list[EventOut] = Field(default_factory=list)


class EventAvailabilityOut(BaseModel):
    """Summary for notification badges."""

    available_slots: int = Field(ge=0)
    bookable_events: int = Field(ge=0)


class EventDatesResponse(BaseModel):
    """Dates with published events (for calendar marking)."""

    duty_dates: list[date] = Field(default_factory=list)
    event_dates: list[date] = Field(default_factory=list)


class EventBookResponse(BaseModel):
    slot: EventSlotOut
    event: EventOut


class EventAdminBookIn(BaseModel):
    user_id: UUID
