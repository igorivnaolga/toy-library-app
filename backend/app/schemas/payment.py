"""Payment ledger API models."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class PaymentOut(BaseModel):
    payment_id: uuid.UUID
    user_id: uuid.UUID
    payment_type: str
    amount_cents: int = Field(ge=1)
    currency: str = "NZD"
    status: str
    description: str | None = None
    booking_id: uuid.UUID | None = None
    loan_id: uuid.UUID | None = None
    toy_id: str | None = None
    recorded_by: uuid.UUID | None = None
    paid_at: datetime | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class PaymentsListResponse(BaseModel):
    data: list[PaymentOut]


class MarkPaymentPaidIn(BaseModel):
    method: Literal["cash", "eftpos", "bank"]


class MarkMembershipPaidIn(BaseModel):
    method: Literal["cash", "eftpos", "bank"]


def payment_out_from_model(payment) -> PaymentOut:
    return PaymentOut(
        payment_id=payment.id,
        user_id=payment.user_id,
        payment_type=payment.payment_type,
        amount_cents=payment.amount_cents,
        currency=payment.currency,
        status=payment.status,
        description=payment.description,
        booking_id=payment.booking_id,
        loan_id=payment.loan_id,
        toy_id=payment.toy_id,
        recorded_by=payment.recorded_by,
        paid_at=payment.paid_at,
        created_at=payment.created_at,
    )
