"""Payment ledger endpoints."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.auth_deps import get_current_principal, require_admin, require_on_duty_desk
from app.db.session import get_db
from app.repositories.profile_repo import get_profile_by_id
from app.schemas.payment import (
    MarkMembershipPaidIn,
    MarkPaymentPaidIn,
    PaymentOut,
    PaymentsListResponse,
    payment_out_from_model,
)
from app.schemas.principal import Principal
from app.services.payment_service import (
    PaymentError,
    list_user_payments_service,
    mark_all_membership_payments_paid,
    mark_payment_paid,
)

router = APIRouter()

_require_on_duty = require_on_duty_desk()


def _http_error(exc: PaymentError) -> HTTPException:
    status = 400
    if exc.code == "payment_not_found":
        status = 404
    elif exc.code in {"payment_not_pending", "no_pending_membership"}:
        status = 409
    return HTTPException(status_code=status, detail=exc.message)


@router.get("/me", response_model=PaymentsListResponse)
def list_my_payments(
    principal: Principal = Depends(get_current_principal),
    db: Session = Depends(get_db),
) -> PaymentsListResponse:
    rows = list_user_payments_service(db, principal.id)
    return PaymentsListResponse(
        data=[payment_out_from_model(row) for row in rows],
    )


@router.get("/users/{user_id}", response_model=PaymentsListResponse)
def list_member_payments_admin(
    user_id: uuid.UUID,
    _: Principal = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PaymentsListResponse:
    profile = get_profile_by_id(db, user_id)
    if profile is None or profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    rows = list_user_payments_service(db, user_id)
    return PaymentsListResponse(
        data=[payment_out_from_model(row) for row in rows],
    )


@router.post("/{payment_id}/mark-paid", response_model=PaymentOut)
def mark_payment_paid_endpoint(
    payment_id: uuid.UUID,
    body: MarkPaymentPaidIn,
    principal: Principal = Depends(_require_on_duty),
    db: Session = Depends(get_db),
) -> PaymentOut:
    try:
        payment = mark_payment_paid(
            db,
            payment_id,
            method=body.method,
            recorded_by=principal.id,
        )
    except PaymentError as exc:
        raise _http_error(exc) from exc
    db.commit()
    db.refresh(payment)
    return payment_out_from_model(payment)


@router.post("/users/{user_id}/mark-membership-paid", response_model=PaymentsListResponse)
def mark_membership_paid_endpoint(
    user_id: uuid.UUID,
    body: MarkMembershipPaidIn,
    principal: Principal = Depends(_require_on_duty),
    db: Session = Depends(get_db),
) -> PaymentsListResponse:
    profile = get_profile_by_id(db, user_id)
    if profile is None or profile.role not in ("member", "volunteer"):
        raise HTTPException(status_code=404, detail="Member not found")
    try:
        payments = mark_all_membership_payments_paid(
            db,
            user_id,
            method=body.method,
            recorded_by=principal.id,
        )
    except PaymentError as exc:
        raise _http_error(exc) from exc
    db.commit()
    for payment in payments:
        db.refresh(payment)
    return PaymentsListResponse(
        data=[payment_out_from_model(row) for row in payments],
    )
