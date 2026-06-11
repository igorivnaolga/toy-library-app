"""Payment ledger rows (see `backend/supabase/snippets/015_payments.sql`)."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base

PAYMENT_TYPE_MEMBERSHIP = "membership"
PAYMENT_TYPE_BOND = "bond"
PAYMENT_TYPE_RENTAL = "rental"

PAYMENT_TYPES = frozenset(
    {PAYMENT_TYPE_MEMBERSHIP, PAYMENT_TYPE_BOND, PAYMENT_TYPE_RENTAL}
)

PAYMENT_STATUS_PENDING = "pending"
PAYMENT_STATUS_PAID_CASH = "paid_cash"
PAYMENT_STATUS_PAID_EFTPOS = "paid_eftpos"
PAYMENT_STATUS_PAID_BANK = "paid_bank"
PAYMENT_STATUS_REFUNDED = "refunded"
PAYMENT_STATUS_CANCELLED = "cancelled"

PAID_STATUSES = frozenset(
    {
        PAYMENT_STATUS_PAID_CASH,
        PAYMENT_STATUS_PAID_EFTPOS,
        PAYMENT_STATUS_PAID_BANK,
    }
)

MEMBERSHIP_PAYMENT_TYPES = frozenset({PAYMENT_TYPE_MEMBERSHIP, PAYMENT_TYPE_BOND})


class Payment(Base):
    __tablename__ = "payments"

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
    payment_type: Mapped[str] = mapped_column(String(32), nullable=False)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(
        String(8),
        nullable=False,
        server_default=text("'NZD'"),
    )
    status: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text(f"'{PAYMENT_STATUS_PENDING}'"),
        index=True,
    )
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    booking_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True,
    )
    loan_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("loans.id", ondelete="SET NULL"),
        nullable=True,
    )
    toy_id: Mapped[str | None] = mapped_column(
        String(32),
        ForeignKey("toys.toy_id", ondelete="SET NULL"),
        nullable=True,
    )
    recorded_by: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("profiles.id", ondelete="SET NULL"),
        nullable=True,
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    user: Mapped["Profile"] = relationship(
        back_populates="payments",
        foreign_keys=[user_id],
    )
