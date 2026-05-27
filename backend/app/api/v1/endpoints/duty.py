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
from app.repositories.profile_repo import search_members_for_desk
from app.schemas.duty import (
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


@router.get("/sessions", response_model=DutySessionsListResponse)
def list_sessions(
    from_date: date = Query(..., alias="from"),
    to_date: date = Query(..., alias="to"),
    _: Principal = Depends(_require_volunteer),
    db: Session = Depends(get_db),
) -> DutySessionsListResponse:
    if to_date < from_date:
        raise HTTPException(status_code=422, detail="`to` must be on or after `from`.")
    rows = list_duty_sessions(db, from_date=from_date, to_date=to_date)
    return DutySessionsListResponse(
        data=[duty_session_out_from_model(row) for row in rows],
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
        session=duty_session_out_from_model(active),
    )


@router.get("/members", response_model=DeskMembersResponse)
def search_desk_members(
    q: str = Query(..., min_length=2, description="Member name, email, or id."),
    _: Principal = Depends(_require_on_duty),
    db: Session = Depends(get_db),
) -> DeskMembersResponse:
    rows = search_members_for_desk(db, q)
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
    return duty_session_out_from_model(row)


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
    return duty_session_out_from_model(row)


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
    return duty_session_out_from_model(row)
