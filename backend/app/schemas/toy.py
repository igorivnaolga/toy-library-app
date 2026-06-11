from pydantic import BaseModel, Field, field_validator

from app.core import availability as avail
from app.utils.text import capitalize_first_letter


class ToyPieceLineOut(BaseModel):
    """One SETLS piece entry for desk staff (from ``setls_pieces_export.csv``)."""

    name: str
    quantity: int = Field(ge=1)
    missing: int = Field(default=0, ge=0)


class ToyPieceLineIn(BaseModel):
    """Editable piece line saved to ``toys.piece_inventory``."""

    name: str = Field(min_length=1)
    quantity: int = Field(ge=1)
    missing: int = Field(default=0, ge=0)

    @field_validator("name", mode="before")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        if not isinstance(value, str):
            return value
        return value.strip()

    @field_validator("missing")
    @classmethod
    def _missing_within_quantity(cls, missing: int, info) -> int:
        quantity = info.data.get("quantity")
        if quantity is not None and missing > quantity:
            raise ValueError("missing cannot exceed quantity")
        return missing


class ToyOut(BaseModel):
    toy_id: str
    name: str
    category: str | None = None
    age_range: str | None = None
    status: str | None = Field(
        default=None,
        description='Raw status label from CSV/DB (e.g. "In library", "On loan").',
    )

    availability: str = Field(
        default=avail.UNKNOWN,
        description="Canonical lending code: available | on_loan | reserved | unavailable | unknown.",
    )
    manufacturer: str | None = None
    description: str | None = None
    photo_file: str | None = None
    total_pieces: int | None = Field(
        default=None,
        ge=0,
        description="Expected number of pieces in the toy set.",
    )
    missing_pieces: int | None = Field(
        default=None,
        ge=0,
        description="Pieces currently known to be missing from the set.",
    )
    missing_pieces_detail: str | None = Field(
        default=None,
        description="Which pieces are missing, when recorded at desk check-in.",
    )
    rental_price_cents: int | None = Field(
        default=None,
        ge=0,
        description="Toy rental price in NZD cents (from SETLS).",
    )
    piece_lines: list[ToyPieceLineOut] | None = Field(
        default=None,
        description="SETLS piece breakdown; included for admin/volunteer toy detail only.",
    )

    @field_validator("name", mode="before")
    @classmethod
    def _capitalize_name(cls, value: str) -> str:
        if not isinstance(value, str):
            return value
        return capitalize_first_letter(value)


class ToysListMeta(BaseModel):
    page: int
    limit: int
    total: int
    has_next: bool


class ToysListResponse(BaseModel):
    data: list[ToyOut]
    meta: ToysListMeta


class ToyCreate(BaseModel):
    """Admin creates a new DB-backed toy (toy_id assigned by the server)."""

    name: str = Field(min_length=1)
    category: str | None = None
    age_range: str | None = None
    status: str | None = Field(default="In library")
    manufacturer: str | None = None
    description: str | None = None
    total_pieces: int | None = Field(default=None, ge=0)
    missing_pieces: int | None = Field(default=None, ge=0)
    rental_price_cents: int | None = Field(default=None, ge=0)


class ToyUpdate(BaseModel):
    """Admin edits to catalog metadata (DB-backed toys only)."""

    name: str | None = Field(default=None, min_length=1)
    category: str | None = None
    age_range: str | None = None
    status: str | None = None
    manufacturer: str | None = None
    description: str | None = None
    total_pieces: int | None = Field(default=None, ge=0)
    missing_pieces: int | None = Field(default=None, ge=0)
    rental_price_cents: int | None = Field(default=None, ge=0)


class ToyPiecesUpdate(BaseModel):
    """Desk update of piece counts (on-duty volunteer or admin)."""

    total_pieces: int | None = Field(default=None, ge=0)
    missing_pieces: int | None = Field(default=None, ge=0)
    piece_lines: list[ToyPieceLineIn] | None = Field(
        default=None,
        description="Full piece inventory; replaces SETLS breakdown when saved.",
    )


class ToysMetaOut(BaseModel):
    """Distinct filter values derived from the current toy dataset (DB or CSV fallback)."""

    age_ranges: list[str] = Field(
        default_factory=list,
        description="Non-empty distinct age_range labels, sorted case-insensitively.",
    )
