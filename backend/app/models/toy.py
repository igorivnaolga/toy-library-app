from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Toy(Base):
    __tablename__ = "toys"

    toy_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    name: Mapped[str] = mapped_column(Text, index=True)

    category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True, index=True
    )
    age_range: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    manufacturer: Mapped[str | None] = mapped_column(Text, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    total_pieces: Mapped[int | None] = mapped_column(Integer, nullable=True)
    missing_pieces: Mapped[int | None] = mapped_column(Integer, nullable=True)
    missing_pieces_detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    piece_inventory: Mapped[str | None] = mapped_column(Text, nullable=True)
    rental_price_cents: Mapped[int | None] = mapped_column(Integer, nullable=True)

    cv_learn_piece_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_learn_fg_pixels: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_learn_peak_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_learn_samples: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    cv_ref_piece_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_ref_fg_pixels: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_ref_peak_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_ref_blob_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_ref_image_area: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cv_ref_layout: Mapped[str | None] = mapped_column(Text, nullable=True)
    cv_ref_source: Mapped[str | None] = mapped_column(String(16), nullable=True)

    category_label: Mapped[str | None] = mapped_column(Text, nullable=True, index=True)

    category_rel: Mapped["Category | None"] = relationship(back_populates="toys")
    image: Mapped["ToyImage | None"] = relationship(
        back_populates="toy", uselist=False, cascade="all, delete-orphan"
    )
    bookings: Mapped[list["Booking"]] = relationship(back_populates="toy")
    loans: Mapped[list["Loan"]] = relationship(back_populates="toy")
