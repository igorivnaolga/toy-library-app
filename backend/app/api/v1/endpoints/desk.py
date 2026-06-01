"""Volunteer desk endpoints (on-duty volunteers and admins)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from app.core.auth_deps import require_on_duty_desk
from app.schemas.principal import Principal
from app.schemas.toy import ToyOut, ToyPiecesUpdate
from app.services.toy_service import update_toy_pieces_service

router = APIRouter()

_require_on_duty = require_on_duty_desk()


@router.patch("/toys/{toy_id}/pieces", response_model=ToyOut)
def update_toy_pieces(
    toy_id: str,
    body: ToyPiecesUpdate,
    _: Principal = Depends(_require_on_duty),
) -> ToyOut:
    """Update piece counts while on desk duty."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    updated = update_toy_pieces_service(
        toy_id,
        total_pieces=payload.get("total_pieces"),
        missing_pieces=payload.get("missing_pieces"),
    )
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return updated
