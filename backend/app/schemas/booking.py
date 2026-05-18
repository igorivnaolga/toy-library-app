"""Booking API request/response models."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.booking import (
    BOOKING_STATUS_CANCELLED,
    BOOKING_STATUS_COMPLETED,
    BOOKING_STATUS_PENDING,
    Booking,
)


class BookingCreate(BaseModel):
    """Member creates a reservation for one toy."""

    toy_id: str = Field(min_length=1, max_length=32, description="Catalog toy_id.")


class BookingOut(BaseModel):
    booking_id: str
    user_id: str
    toy_id: str
    toy_name: str | None = None
    status: str = Field(
        description=f"One of: {BOOKING_STATUS_PENDING}, {BOOKING_STATUS_CANCELLED}, {BOOKING_STATUS_COMPLETED}.",
    )
    created_at: datetime
    cancelled_at: datetime | None = None


class BookingsListResponse(BaseModel):
    data: list[BookingOut]


def booking_out_from_model(booking: Booking) -> BookingOut:
    """Map SQLAlchemy ``Booking`` (+ optional loaded ``toy``) to API JSON."""
    toy_name = booking.toy.name if getattr(booking, "toy", None) is not None else None
    return BookingOut(
        booking_id=str(booking.id),
        user_id=str(booking.user_id),
        toy_id=booking.toy_id,
        toy_name=toy_name,
        status=booking.status,
        created_at=booking.created_at,
        cancelled_at=booking.cancelled_at,
    )
