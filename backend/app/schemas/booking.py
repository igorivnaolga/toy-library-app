"""Booking API request/response models."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator

from app.core.library_sessions import format_pickup_label
from app.utils.text import capitalize_first_letter
from app.models.booking import (
    BOOKING_STATUS_CANCELLED,
    BOOKING_STATUS_COMPLETED,
    BOOKING_STATUS_PENDING,
    Booking,
)


class BookingCreate(BaseModel):
    """Member creates a reservation for one toy."""

    toy_id: str = Field(min_length=1, max_length=32, description="Catalog toy_id.")
    pickup_date: date = Field(
        description="Library session day for pickup (Wednesday or Saturday, within 6 months).",
    )


class BookingReschedule(BaseModel):
    """Member changes pickup day on a pending booking."""

    pickup_date: date = Field(
        description="New library session day (Wednesday or Saturday, within 6 months).",
    )


class BookingOut(BaseModel):
    booking_id: str
    user_id: str
    toy_id: str
    toy_name: str | None = None
    photo_file: str | None = Field(
        None,
        description="Catalog image filename for the toy, if any.",
    )
    member_name: str | None = Field(
        None,
        description="Member full name when loaded for volunteer desk views.",
    )
    member_email: str | None = Field(
        None,
        description="Member email when loaded for volunteer desk views.",
    )
    status: str = Field(
        description=f"One of: {BOOKING_STATUS_PENDING}, {BOOKING_STATUS_CANCELLED}, {BOOKING_STATUS_COMPLETED}.",
    )
    pickup_date: date | None = None
    pickup_label: str | None = Field(
        None,
        description='Display label, e.g. "Wednesday 21 May".',
    )
    created_at: datetime
    cancelled_at: datetime | None = None

    @field_validator("toy_name", mode="before")
    @classmethod
    def _capitalize_toy_name(cls, value: str | None) -> str | None:
        if value is None or not isinstance(value, str):
            return value
        return capitalize_first_letter(value)


class BookingsListResponse(BaseModel):
    data: list[BookingOut]


class PickupDateOption(BaseModel):
    date: date
    label: str
    weekday: str = Field(description="wednesday or saturday")


class PickupDatesResponse(BaseModel):
    data: list[PickupDateOption]


def booking_out_from_model(
    booking: Booking,
    *,
    member_email: str | None = None,
) -> BookingOut:
    """Map SQLAlchemy ``Booking`` (+ optional loaded ``toy`` / ``profile``) to API JSON."""
    toy = getattr(booking, "toy", None)
    toy_name = toy.name if toy is not None else None
    photo_file = toy.image.filename if toy is not None and toy.image else None
    member_name = None
    profile = getattr(booking, "profile", None)
    if profile is not None and profile.full_name:
        member_name = profile.full_name
    pickup_label = (
        format_pickup_label(booking.pickup_date) if booking.pickup_date else None
    )
    return BookingOut(
        booking_id=str(booking.id),
        user_id=str(booking.user_id),
        toy_id=booking.toy_id,
        toy_name=toy_name,
        photo_file=photo_file,
        member_name=member_name,
        member_email=member_email,
        status=booking.status,
        pickup_date=booking.pickup_date,
        pickup_label=pickup_label,
        created_at=booking.created_at,
        cancelled_at=booking.cancelled_at,
    )
