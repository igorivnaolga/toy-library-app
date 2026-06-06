"""Schemas for AI-assisted desk check-in (piece-count estimate)."""

from __future__ import annotations

from pydantic import BaseModel, Field


class PieceCountEstimate(BaseModel):
    """Advisory piece-count result for a returned-toy photo.

    The volunteer always confirms the final missing-piece count at check-in;
    this estimate only pre-fills a suggestion.
    """

    toy_id: str
    expected_total: int | None = Field(
        default=None,
        description="Pieces expected in the set (from the catalog), if known.",
    )
    estimated_count: int | None = Field(
        default=None,
        description="Pieces detected in the photo, or null if analysis failed.",
    )
    suggested_missing: int | None = Field(
        default=None,
        ge=0,
        description="max(0, expected_total - estimated_count) when both are known.",
    )
    confidence: float = Field(
        ge=0,
        le=1,
        description="Heuristic confidence in the estimate (advisory only).",
    )
    message: str
    catalog_total: int | None = Field(
        default=None,
        description="Piece total from catalog before learning overrides.",
    )
    learned_total: int | None = Field(
        default=None,
        description="Learned piece total from past confirmed check-ins.",
    )
    learn_samples: int = Field(
        default=0,
        ge=0,
        description="How many confirmed photos trained the baseline.",
    )
    reference_source: str | None = Field(
        default=None,
        description="Reference photo origin: setls or checkin.",
    )
    layout_similarity: float | None = Field(
        default=None,
        ge=0,
        le=1,
        description="How closely the desk photo layout matches the reference.",
    )


class LearnFromPhotoResult(BaseModel):
    toy_id: str
    learn_samples: int
    learned_piece_count: int | None = None
    message: str
