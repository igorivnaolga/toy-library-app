"""Loan API request/response models."""

from __future__ import annotations

from datetime import date, datetime

from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.loan import Loan
from app.core.library_sessions import loan_return_session_date
from app.services.loan_service import loan_is_due_today, loan_is_overdue
from app.utils.text import capitalize_first_letter


class _RentalPaymentFields(BaseModel):
    rental_payment: Literal["pending", "paid"] = Field(
        default="pending",
        description="Whether the rental charge stays pending or is marked paid at checkout.",
    )
    payment_method: Literal["cash", "eftpos", "bank"] | None = Field(
        default=None,
        description="Required when rental_payment is paid.",
    )

    @model_validator(mode="after")
    def _paid_requires_method(self) -> "_RentalPaymentFields":
        if self.rental_payment == "paid" and self.payment_method is None:
            raise ValueError("payment_method is required when rental_payment is paid.")
        return self


class LoanCheckOutFromBooking(_RentalPaymentFields):
    booking_id: str = Field(min_length=1, description="Pending booking to check out.")


class LoanCheckOutWalkIn(_RentalPaymentFields):
    user_id: str = Field(min_length=1, description="Member profile id.")
    toy_id: str = Field(min_length=1, max_length=32, description="Catalog toy_id.")


class LoanCheckIn(BaseModel):
    """Optional piece count update when checking a toy back in."""

    missing_pieces: int | None = Field(
        default=None,
        ge=0,
        description="Updated missing piece count after inspection.",
    )
    missing_pieces_detail: str | None = Field(
        default=None,
        max_length=500,
        description="Optional note of which pieces are missing (e.g. H, L).",
    )


class LoanOut(BaseModel):
    loan_id: str
    user_id: str
    toy_id: str
    toy_name: str | None = None
    photo_file: str | None = Field(
        None,
        description="Catalog image filename for the toy, if any.",
    )
    toy_total_pieces: int | None = Field(
        None,
        description="Expected pieces in the toy set when loaded for desk views.",
    )
    toy_missing_pieces: int | None = Field(
        None,
        description="Known missing pieces when loaded for desk views.",
    )
    member_name: str | None = Field(
        None,
        description="Borrower full name when loaded for volunteer desk views.",
    )
    booking_id: str | None = None
    status: str
    checked_out_at: datetime
    due_date: date
    return_session_date: date = Field(
        description="First Wed/Sat library session on or after due_date.",
    )
    returned_at: datetime | None = None
    renewal_count: int = 0
    max_renewals: int | None = Field(
        None,
        description="Category limit for renewals (null if unknown).",
    )
    is_overdue: bool = False
    is_due_today: bool = False
    renewals_remaining: int | None = None

    @field_validator("toy_name", mode="before")
    @classmethod
    def _capitalize_toy_name(cls, value: str | None) -> str | None:
        if value is None or not isinstance(value, str):
            return value
        return capitalize_first_letter(value)


class LoansListResponse(BaseModel):
    data: list[LoanOut]


def loan_out_from_model(
    loan: Loan,
    *,
    max_renewals: int | None = None,
    renewals_remaining: int | None = None,
) -> LoanOut:
    toy = getattr(loan, "toy", None)
    toy_name = toy.name if toy is not None else None
    photo_file = toy.image.filename if toy is not None and toy.image else None
    toy_total_pieces = None
    toy_missing_pieces = None
    if toy is not None:
        toy_total_pieces = toy.total_pieces
        toy_missing_pieces = toy.missing_pieces
    member_name = None
    profile = getattr(loan, "profile", None)
    if profile is not None and profile.full_name:
        member_name = profile.full_name
    if renewals_remaining is None and max_renewals is not None:
        renewals_remaining = max(0, max_renewals - loan.renewal_count)
    return LoanOut(
        loan_id=str(loan.id),
        user_id=str(loan.user_id),
        toy_id=loan.toy_id,
        toy_name=toy_name,
        photo_file=photo_file,
        toy_total_pieces=toy_total_pieces,
        toy_missing_pieces=toy_missing_pieces,
        member_name=member_name,
        booking_id=str(loan.booking_id) if loan.booking_id else None,
        status=loan.status,
        checked_out_at=loan.checked_out_at,
        due_date=loan.due_date,
        return_session_date=loan_return_session_date(loan.due_date),
        returned_at=loan.returned_at,
        renewal_count=loan.renewal_count,
        max_renewals=max_renewals,
        is_overdue=loan_is_overdue(loan),
        is_due_today=loan_is_due_today(loan),
        renewals_remaining=renewals_remaining,
    )
