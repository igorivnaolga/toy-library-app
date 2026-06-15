"""Library events — member/volunteer booking."""

from __future__ import annotations

import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.auth_deps import require_roles
from app.core.library_sessions import library_now
from app.core.roles import Role
from app.db.session import get_db
from app.schemas.event import (
    EventAvailabilityOut,
    EventBookResponse,
    EventDatesResponse,
    EventOut,
    EventsListResponse,
)
from app.schemas.principal import Principal
from app.repositories.event_repo import get_event_by_id
from app.services.event_service import (
    EventError,
    availability_for_user,
    book_slot_service,
    cancel_booking_service,
    event_out_from_model,
    list_events_for_user,
    schedule_dates_in_range,
    slot_out_from_model,
)

router = APIRouter()

_require_member = require_roles(Role.MEMBER, Role.VOLUNTEER, Role.ADMIN)


def _event_http_error(exc: EventError) -> HTTPException:
    status = 400
    if exc.code == "not_found":
        status = 404
    elif exc.code in {"full", "already_booked", "not_booked"}:
        status = 409
    elif exc.code in {"not_allowed", "wrong_audience", "unpublished"}:
        status = 403
    return HTTPException(status_code=status, detail=exc.message)


@router.get("", response_model=EventsListResponse)
def list_events(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    principal: Principal = Depends(_require_member),
    db: Session = Depends(get_db),
) -> EventsListResponse:
    if to_date < from_date:
        raise HTTPException(status_code=422, detail="`to` must be on or after `from`.")
    rows = list_events_for_user(
        db,
        from_date=from_date,
        to_date=to_date,
        current_user_id=principal.id,
        role=principal.role,
        published_only=True,
    )
    return EventsListResponse(data=rows)


@router.get("/availability", response_model=EventAvailabilityOut)
def event_availability(
    principal: Principal = Depends(_require_member),
    db: Session = Depends(get_db),
) -> EventAvailabilityOut:
    today = library_now().date()
    to_date = today + timedelta(days=365)
    slots, events = availability_for_user(
        db,
        current_user_id=principal.id,
        role=principal.role,
        from_date=today,
        to_date=to_date,
    )
    return EventAvailabilityOut(
        available_slots=slots,
        bookable_events=events,
    )


@router.get("/dates", response_model=EventDatesResponse)
def schedule_dates(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    _: Principal = Depends(_require_member),
    db: Session = Depends(get_db),
) -> EventDatesResponse:
    if to_date < from_date:
        raise HTTPException(status_code=422, detail="`to` must be on or after `from`.")
    duty_dates, event_dates = schedule_dates_in_range(
        db, from_date=from_date, to_date=to_date
    )
    return EventDatesResponse(duty_dates=duty_dates, event_dates=event_dates)


@router.post("/slots/{slot_id}/book", response_model=EventBookResponse)
def book_event_slot(
    slot_id: uuid.UUID,
    principal: Principal = Depends(_require_member),
    db: Session = Depends(get_db),
) -> EventBookResponse:
    if principal.role == Role.ADMIN:
        raise HTTPException(status_code=403, detail="Admins cannot book event slots.")
    try:
        booked_slot_id, event_id = book_slot_service(
            db,
            slot_id=slot_id,
            user_id=principal.id,
            role=principal.role,
        )
    except EventError as exc:
        raise _event_http_error(exc) from exc
    db.commit()
    event = get_event_by_id(db, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found.")
    slot_model = next((s for s in event.slots if s.id == booked_slot_id), None)
    if slot_model is None:
        raise HTTPException(status_code=404, detail="Time slot not found.")
    return EventBookResponse(
        slot=slot_out_from_model(db, slot_model, current_user_id=principal.id),
        event=event_out_from_model(db, event, current_user_id=principal.id),
    )


@router.delete("/slots/{slot_id}/book", response_model=EventBookResponse)
def cancel_event_booking(
    slot_id: uuid.UUID,
    principal: Principal = Depends(_require_member),
    db: Session = Depends(get_db),
) -> EventBookResponse:
    try:
        cancelled_slot_id, event_id = cancel_booking_service(
            db,
            slot_id=slot_id,
            user_id=principal.id,
            role=principal.role,
        )
    except EventError as exc:
        raise _event_http_error(exc) from exc
    db.commit()
    event = get_event_by_id(db, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Event not found.")
    slot_model = next((s for s in event.slots if s.id == cancelled_slot_id), None)
    if slot_model is None:
        raise HTTPException(status_code=404, detail="Time slot not found.")
    return EventBookResponse(
        slot=slot_out_from_model(db, slot_model, current_user_id=principal.id),
        event=event_out_from_model(db, event, current_user_id=principal.id),
    )
