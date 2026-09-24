"""Member toy reservations (see `backend/migrations/sql/baseline/003_bookings.sql`)."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Index, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base

# Stored in `bookings.status`; keep in sync with SQL check constraint.
BOOKING_STATUS_PENDING = "pending"
BOOKING_STATUS_CANCELLED = "cancelled"
BOOKING_STATUS_COMPLETED = "completed"

BOOKING_STATUSES = frozenset(
    {
        BOOKING_STATUS_PENDING,
        BOOKING_STATUS_CANCELLED,
        BOOKING_STATUS_COMPLETED,
    }
)


class Booking(Base):
    __tablename__ = "bookings"
    __table_args__ = (
        # At most one pending booking per toy (and per member + toy).
        Index(
            "idx_bookings_one_pending_per_toy",
            "toy_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
        ),
        Index(
            "idx_bookings_one_pending_per_user_toy",
            "user_id",
            "toy_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        # RESTRICT: booking history must not vanish when an account is deleted.
        ForeignKey("profiles.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    toy_id: Mapped[str] = mapped_column(
        String(32),
        ForeignKey("toys.toy_id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text(f"'{BOOKING_STATUS_PENDING}'"),
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    pickup_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        server_default=func.now(),
        onupdate=func.now(),
    )

    profile: Mapped["Profile"] = relationship(back_populates="bookings")
    toy: Mapped["Toy"] = relationship(back_populates="bookings")
    loan: Mapped["Loan | None"] = relationship(back_populates="booking", uselist=False)
