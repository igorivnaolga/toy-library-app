"""Active toy loans after volunteer/member check-out."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base

LOAN_STATUS_ACTIVE = "active"
LOAN_STATUS_RETURNED = "returned"

LOAN_STATUSES = frozenset({LOAN_STATUS_ACTIVE, LOAN_STATUS_RETURNED})

# Default loan length (days); each renewal extends by the same period.
DEFAULT_LOAN_DAYS = 14


class Loan(Base):
    __tablename__ = "loans"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("profiles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    toy_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey("toys.toy_id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True,
    )
    checked_out_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    due_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    returned_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    renewal_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        server_default=text("0"),
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text(f"'{LOAN_STATUS_ACTIVE}'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        server_default=func.now(),
        onupdate=func.now(),
    )

    profile: Mapped["Profile"] = relationship(back_populates="loans")
    toy: Mapped["Toy"] = relationship(back_populates="loans")
    booking: Mapped["Booking | None"] = relationship(back_populates="loan")
