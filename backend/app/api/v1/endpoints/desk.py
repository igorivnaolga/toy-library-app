"""Volunteer desk endpoints (on-duty volunteers and admins)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth_deps import require_on_duty_desk
from app.schemas.desk_cv import PieceCountEstimate
from app.schemas.principal import Principal
from app.schemas.toy import ToyOut, ToyPiecesUpdate
from app.services.desk_cv_service import estimate_pieces_service
from app.services.toy_service import update_toy_pieces_service

router = APIRouter()

_require_on_duty = require_on_duty_desk()

_MAX_UPLOAD_BYTES = 8 * 1024 * 1024


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


@router.post("/identify-pieces", response_model=PieceCountEstimate)
async def identify_pieces(
    toy_id: str = Form(...),
    image: UploadFile = File(...),
    _: Principal = Depends(_require_on_duty),
) -> PieceCountEstimate:
    """Advisory piece-count estimate from a returned-toy photo."""
    data = await image.read()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image upload.")
    if len(data) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image is too large.")
    estimate = estimate_pieces_service(toy_id, data)
    if estimate is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return estimate
