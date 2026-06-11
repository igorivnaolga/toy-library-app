"""Maps `public.profiles` — app roles for Supabase-authenticated users."""

from __future__ import annotations

import uuid

from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, String, text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Profile(Base):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        doc="Matches Supabase auth.users.id",
    )
    role: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default=text("'guest'"),
    )
    full_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    membership_tier: Mapped[str | None] = mapped_column(String(32), nullable=True)
    volunteer_confirmed: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        server_default=text("false"),
    )
    kids_names: Mapped[list[str]] = mapped_column(
        ARRAY(String),
        nullable=False,
        server_default=text("'{}'"),
    )
    kids: Mapped[list[dict]] = mapped_column(
        JSONB,
        nullable=False,
        server_default=text("'[]'"),
    )
    avatar_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    admin_notes: Mapped[str | None] = mapped_column(String(2000), nullable=True)
    parent_b_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address_line1: Mapped[str | None] = mapped_column(String(255), nullable=True)
    address_line2: Mapped[str | None] = mapped_column(String(255), nullable=True)
    suburb: Mapped[str | None] = mapped_column(String(128), nullable=True)
    mobile_phone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    alt_contact_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    alt_contact_address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    alt_contact_phone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    heard_about_us: Mapped[str | None] = mapped_column(String(500), nullable=True)
    skills: Mapped[str | None] = mapped_column(String(500), nullable=True)
    text_reminders_consent: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    terms_accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    registered_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    bookings: Mapped[list["Booking"]] = relationship(back_populates="profile")
    loans: Mapped[list["Loan"]] = relationship(back_populates="profile")
    duty_sessions: Mapped[list["DutySession"]] = relationship(
        back_populates="volunteer",
        foreign_keys="DutySession.volunteer_id",
    )
    device_tokens: Mapped[list["DeviceToken"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )
    payments: Mapped[list["Payment"]] = relationship(
        back_populates="user",
        foreign_keys="Payment.user_id",
    )
