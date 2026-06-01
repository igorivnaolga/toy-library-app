"""Loan endpoints: check-out, check-in, renew, list."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.auth_deps import require_on_duty_desk, require_roles
from app.core.roles import Role
from app.db.session import get_db
from app.models.category import Category
from app.models.toy import Toy
from app.schemas.loan import (
    LoanCheckIn,
    LoanCheckOutFromBooking,
    LoanCheckOutWalkIn,
    LoanOut,
    LoansListResponse,
    loan_out_from_model,
)
from app.schemas.principal import Principal
from app.services.loan_service import (
    LoanError,
    check_in_loan,
    check_out_from_booking,
    check_out_walk_in as check_out_walk_in_service,
    list_active_loans_service,
    list_my_loans_service,
    renew_loan_for_user,
)

router = APIRouter()

_require_member = require_roles(Role.MEMBER, Role.VOLUNTEER, Role.ADMIN)
_require_on_duty = require_on_duty_desk()


def _http_error(exc: LoanError) -> HTTPException:
    status = 400
    if exc.code in {"booking_not_found", "loan_not_found", "toy_not_found", "catalog_not_seeded"}:
        status = 404
    elif exc.code in {
        "toy_not_available",
        "toy_on_loan",
        "booking_not_checkoutable",
        "loan_not_active",
        "loan_not_renewable",
        "renewals_exhausted",
        "pickup_not_due",
        "invalid_missing_pieces",
    }:
        status = 409
    return HTTPException(status_code=status, detail=exc.message)


def _max_renewals_for_loan(db: Session, loan) -> int | None:
    toy = loan.toy
    if toy is None:
        toy = db.get(Toy, loan.toy_id)
    if toy is None or toy.category_id is None:
        return None
    category = db.get(Category, toy.category_id)
    if category is None or category.max_renewals is None:
        return None
    return category.max_renewals


@router.get("/me", response_model=LoansListResponse)
def list_my_loans(
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
    active_only: bool = Query(False, description="Return only active loans."),
) -> LoansListResponse:
    rows = list_my_loans_service(db, principal.id, active_only=active_only)
    return LoansListResponse(
        data=[
            loan_out_from_model(row, max_renewals=_max_renewals_for_loan(db, row))
            for row in rows
        ],
    )


@router.get("/active", response_model=LoansListResponse)
def list_active_loans(
    db: Session = Depends(get_db),
    _: Principal = Depends(_require_on_duty),
) -> LoansListResponse:
    """Volunteer desk: all toys currently on loan."""
    rows = list_active_loans_service(db)
    return LoansListResponse(
        data=[
            loan_out_from_model(row, max_renewals=_max_renewals_for_loan(db, row))
            for row in rows
        ],
    )


@router.post("/check-out/booking", response_model=LoanOut)
def check_out_booking(
    body: LoanCheckOutFromBooking,
    db: Session = Depends(get_db),
    _: Principal = Depends(_require_on_duty),
) -> LoanOut:
    try:
        loan = check_out_from_booking(db, uuid.UUID(body.booking_id))
    except LoanError as e:
        raise _http_error(e) from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail="Invalid booking_id") from e
    db.commit()
    return loan_out_from_model(loan, max_renewals=_max_renewals_for_loan(db, loan))


@router.post("/check-out/walk-in", response_model=LoanOut)
def check_out_walk_in(
    body: LoanCheckOutWalkIn,
    db: Session = Depends(get_db),
    _: Principal = Depends(_require_on_duty),
) -> LoanOut:
    try:
        loan = check_out_walk_in_service(
            db,
            user_id=uuid.UUID(body.user_id),
            toy_id=body.toy_id,
        )
    except LoanError as e:
        raise _http_error(e) from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail="Invalid user_id") from e
    db.commit()
    return loan_out_from_model(loan, max_renewals=_max_renewals_for_loan(db, loan))


@router.post("/{loan_id}/check-in", response_model=LoanOut)
def check_in(
    loan_id: uuid.UUID,
    body: LoanCheckIn | None = None,
    db: Session = Depends(get_db),
    _: Principal = Depends(_require_on_duty),
) -> LoanOut:
    try:
        missing = body.missing_pieces if body is not None else None
        loan = check_in_loan(db, loan_id, missing_pieces=missing)
    except LoanError as e:
        raise _http_error(e) from e
    db.commit()
    return loan_out_from_model(loan, max_renewals=_max_renewals_for_loan(db, loan))


@router.post("/{loan_id}/renew", response_model=LoanOut)
def renew_loan(
    loan_id: uuid.UUID,
    db: Session = Depends(get_db),
    principal: Principal = Depends(_require_member),
) -> LoanOut:
    try:
        loan = renew_loan_for_user(db, principal.id, loan_id)
    except LoanError as e:
        raise _http_error(e) from e
    db.commit()
    return loan_out_from_model(loan, max_renewals=_max_renewals_for_loan(db, loan))
