from pydantic import BaseModel, Field, field_validator

from app.core import availability as avail
from app.utils.text import capitalize_first_letter


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
    rental_price_cents: int | None = Field(
        default=None,
        ge=0,
        description="Toy rental price in NZD cents (from SETLS).",
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


class ToysMetaOut(BaseModel):
    """Distinct filter values derived from the current toy dataset (DB or CSV fallback)."""

    age_ranges: list[str] = Field(
        default_factory=list,
        description="Non-empty distinct age_range labels, sorted case-insensitively.",
    )
