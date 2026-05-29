"""Member booking endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth_deps import require_booking_member, require_on_duty_desk
from app.db.session import get_db
from app.schemas.booking import (
    BookingCreate,
    BookingOut,
    BookingReschedule,
    BookingsListResponse,
    PickupDateOption,
    PickupDatesResponse,
    booking_out_from_model,
)
from app.schemas.principal import Principal
from app.services.booking_service import (
    BookingError,
    cancel_booking_for_user,
    create_booking_for_user,
    list_bookings_for_user_service,
    list_pending_bookings_for_checkout_service,
    list_pickup_date_options,
    reschedule_booking_for_user,
)

router = APIRouter()

_require_member = require_booking_member()
_require_on_duty = require_on_duty_desk()


def _http_error(exc: BookingError) -> HTTPException:
    status = 400
    if exc.code in {"toy_not_found", "booking_not_found", "catalog_not_seeded"}:
        status = 404
    elif exc.code in {
        "toy_not_available",
        "toy_already_reserved",
        "booking_not_cancellable",
        "booking_not_reschedulable",
    }:
        status = 409
    elif exc.code == "invalid_pickup_date":
        status = 422
    return HTTPException(status_code=status, detail=exc.message)


@router.get("/pickup-dates", response_model=PickupDatesResponse)
def list_pickup_dates(
    _: Principal = Depends(_require_member),
) -> PickupDatesResponse:
    """Wed/Sat session dates available for new bookings (4-week horizon)."""
    rows = list_pickup_date_options()
    return PickupDatesResponse(
        data=[PickupDateOption.model_validate(row) for row in rows],
    )


@router.post("", response_model=BookingOut)
def create_booking(
    body: BookingCreate,
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> BookingOut:
    """Create a pending reservation for an available toy."""
    try:
        booking = create_booking_for_user(
            db,
            principal.id,
            body.toy_id,
            body.pickup_date,
        )
    except BookingError as e:
        raise _http_error(e) from e
    db.commit()
    return booking_out_from_model(booking)


@router.get("/me", response_model=BookingsListResponse)
def list_my_bookings(
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> BookingsListResponse:
    """List the current user's bookings (newest first)."""
    rows = list_bookings_for_user_service(db, principal.id)
    return BookingsListResponse(
        data=[booking_out_from_model(row) for row in rows],
    )


@router.get("/pending", response_model=BookingsListResponse)
def list_pending_for_checkout(
    db: Session = Depends(get_db),
    _: Principal = Depends(_require_on_duty),
) -> BookingsListResponse:
    """Volunteer desk: pending bookings ready for check-out."""
    rows = list_pending_bookings_for_checkout_service(db)
    return BookingsListResponse(
        data=[booking_out_from_model(row) for row in rows],
    )


@router.patch("/{booking_id}", response_model=BookingOut)
def reschedule_booking(
    booking_id: uuid.UUID,
    body: BookingReschedule,
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> BookingOut:
    """Change pickup day on a pending booking."""
    try:
        booking = reschedule_booking_for_user(
            db,
            principal.id,
            booking_id,
            body.pickup_date,
        )
    except BookingError as e:
        raise _http_error(e) from e
    db.commit()
    return booking_out_from_model(booking)


@router.post("/{booking_id}/cancel", response_model=BookingOut)
def cancel_booking(
    booking_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> BookingOut:
    """Cancel a pending booking and release the toy when still reserved."""
    try:
        booking = cancel_booking_for_user(db, principal.id, booking_id)
    except BookingError as e:
        raise _http_error(e) from e
    db.commit()
    return booking_out_from_model(booking)
