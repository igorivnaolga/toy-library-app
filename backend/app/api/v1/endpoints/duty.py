"""Volunteer duty roster endpoints."""

from __future__ import annotations

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.auth_deps import require_admin, require_on_duty_desk, require_roles
from app.core.library_sessions import library_now
from app.core.roles import Role
from app.db.session import get_db
from app.repositories.duty_repo import (
    book_duty_session,
    cancel_duty_booking,
    create_duty_session,
    delete_duty_session,
    get_active_duty_session_for_volunteer,
    get_duty_session_by_id,
    list_duty_sessions,
)
from app.repositories.profile_repo import list_roster_members, search_members_for_desk
from app.services.duty_service import (
    DutyError,
    assign_volunteer_to_session,
    clear_session_assignment,
    confirm_duty_session_for_admin,
    ensure_roster_sessions,
)
from app.schemas.duty import (
    DutySessionAssign,
    DutySessionCreate,
    DutySessionOut,
    DutySessionsListResponse,
    DeskMemberOut,
    DeskMembersResponse,
    OnDutyResponse,
    duty_session_out_from_model,
)
from app.schemas.principal import Principal

router = APIRouter()

_require_volunteer = require_roles(Role.VOLUNTEER, Role.ADMIN)
_require_on_duty = require_on_duty_desk()


def _duty_http_error(exc: DutyError) -> HTTPException:
    status = 400
    if exc.code == "profile_not_found":
        status = 404
    elif exc.code == "invalid_assignee":
        status = 422
    elif exc.code == "slot_already_assigned":
        status = 409
    elif exc.code in {"slot_unbooked", "not_duty_day"}:
        status = 409
    return HTTPException(status_code=status, detail=exc.message)


@router.get("/sessions", response_model=DutySessionsListResponse)
def list_sessions(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    _: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> DutySessionsListResponse:
    if to_date < from_date:
        raise HTTPException(status_code=422, detail="`to` must be on or after `from`.")
    rows = ensure_roster_sessions(db, from_date=from_date, to_date=to_date)
    db.commit()
    rows = list_duty_sessions(db, from_date=from_date, to_date=to_date)
    return DutySessionsListResponse(
        data=[duty_session_out_from_model(row, db) for row in rows],
    )


@router.get("/me/on-duty", response_model=OnDutyResponse)
def my_on_duty_status(
    principal: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> OnDutyResponse:
    if principal.role == Role.ADMIN:
        return OnDutyResponse(on_duty=True, session=None)
    active = get_active_duty_session_for_volunteer(db, principal.id)
    if active is None:
        return OnDutyResponse(on_duty=False, session=None)
    return OnDutyResponse(
        on_duty=True,
        session=duty_session_out_from_model(active, db),
    )


@router.get("/members", response_model=DeskMembersResponse)
def search_desk_members(
    q: str = Query("", description="Member name, email, or id."),
    _: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> DeskMembersResponse:
    rows = (
        search_members_for_desk(db, q)
        if q.strip()
        else list_roster_members(db)
    )
    return DeskMembersResponse(
        data=[DeskMemberOut.model_validate(row) for row in rows],
    )


@router.post("/sessions", response_model=DutySessionOut)
def create_session(
    body: DutySessionCreate,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    volunteer_id: uuid.UUID | None = None
    if body.volunteer_id:
        try:
            volunteer_id = uuid.UUID(body.volunteer_id)
        except ValueError as e:
            raise HTTPException(status_code=422, detail="Invalid volunteer_id.") from e
    row = create_duty_session(
        db,
        session_date=body.session_date,
        start_time=body.start_time,
        end_time=body.end_time,
        volunteer_id=volunteer_id,
    )
    db.commit()
    db.refresh(row)
    row = get_duty_session_by_id(db, row.id) or row
    return duty_session_out_from_model(row, db)


@router.patch("/sessions/{session_id}/assign", response_model=DutySessionOut)
def assign_session(
    session_id: uuid.UUID,
    body: DutySessionAssign,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    try:
        user_id = uuid.UUID(body.user_id)
    except ValueError as e:
        raise HTTPException(status_code=422, detail="Invalid user_id.") from e
    try:
        assign_volunteer_to_session(db, row, user_id)
    except DutyError as e:
        raise _duty_http_error(e) from e
    db.commit()
    row = get_duty_session_by_id(db, session_id) or row
    return duty_session_out_from_model(row, db)


@router.delete("/sessions/{session_id}/assign", response_model=DutySessionOut)
def clear_session(
    session_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    clear_session_assignment(db, row)
    db.commit()
    row = get_duty_session_by_id(db, session_id) or row
    return duty_session_out_from_model(row, db)


@router.delete("/sessions/{session_id}")
def remove_session(
    session_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> dict[str, bool]:
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    delete_duty_session(db, row)
    db.commit()
    return {"ok": True}


@router.post("/sessions/{session_id}/book", response_model=DutySessionOut)
def book_session(
    session_id: uuid.UUID,
    principal: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    if principal.role == Role.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Admins manage the roster; volunteers book open slots.",
        )
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    if row.volunteer_id is not None:
        raise HTTPException(status_code=409, detail="This slot is already booked.")
    if row.session_date < library_now().date():
        raise HTTPException(status_code=409, detail="Past duty slots cannot be booked.")
    book_duty_session(db, row, principal.id)
    db.commit()
    row = get_duty_session_by_id(db, session_id) or row
    return duty_session_out_from_model(row, db)


@router.post("/sessions/{session_id}/confirm", response_model=DutySessionOut)
def confirm_session(
    session_id: uuid.UUID,
    principal: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    """Admin confirms a volunteer's booked shift on the duty day."""
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    try:
        confirm_duty_session_for_admin(db, row, principal.id)
    except DutyError as e:
        raise _duty_http_error(e) from e
    db.commit()
    row = get_duty_session_by_id(db, session_id) or row
    return duty_session_out_from_model(row, db)


@router.delete("/sessions/{session_id}/book", response_model=DutySessionOut)
def cancel_booking(
    session_id: uuid.UUID,
    principal: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> DutySessionOut:
    row = get_duty_session_by_id(db, session_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Duty session not found.")
    if row.volunteer_id != principal.id and principal.role != Role.ADMIN:
        raise HTTPException(status_code=403, detail="You can only cancel your own booking.")
    cancel_duty_booking(db, row)
    db.commit()
    row = get_duty_session_by_id(db, session_id) or row
    return duty_session_out_from_model(row, db)
