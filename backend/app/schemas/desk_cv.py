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
