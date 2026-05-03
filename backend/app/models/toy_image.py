from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ToyImage(Base):
    __tablename__ = "toy_images"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    toy_id: Mapped[str] = mapped_column(
        String(32), ForeignKey("toys.toy_id", ondelete="CASCADE"), unique=True
    )
    filename: Mapped[str | None] = mapped_column(String(512), nullable=True)

    toy: Mapped["Toy"] = relationship(back_populates="image")
