"""Volunteer desk endpoints (on-duty volunteers and admins)."""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.core.auth_deps import require_on_duty_desk
from app.schemas.desk_cv import LearnFromPhotoResult, PieceCountEstimate
from app.schemas.principal import Principal
from app.schemas.toy import ToyOut, ToyPiecesUpdate
from app.services.desk_cv_service import estimate_pieces_service
from app.services.toy_cv_learner import learn_from_photo_service
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
    try:
        estimate = estimate_pieces_service(toy_id, data)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Photo analysis error: {exc}",
        ) from exc
    if estimate is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    return estimate


@router.post("/learn-from-photo", response_model=LearnFromPhotoResult)
async def learn_from_photo_endpoint(
    toy_id: str = Form(...),
    confirmed_piece_count: int = Form(...),
    image: UploadFile = File(...),
    is_complete_set: str = Form(default="false"),
    _: Principal = Depends(_require_on_duty),
) -> LearnFromPhotoResult:
    """Train per-toy baseline from a volunteer-confirmed check-in photo."""
    if confirmed_piece_count <= 0:
        raise HTTPException(status_code=422, detail="confirmed_piece_count must be positive.")
    data = await image.read()
    if not data:
        raise HTTPException(status_code=422, detail="Empty image upload.")
    if len(data) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image is too large.")
    volunteer_complete = is_complete_set.strip().lower() in {"1", "true", "yes"}
    result = await asyncio.to_thread(
        learn_from_photo_service,
        toy_id,
        data,
        confirmed_piece_count,
        volunteer_complete=volunteer_complete,
    )
    if result is None:
        raise HTTPException(
            status_code=422,
            detail=(
                "Could not save photo learning. Take the photo again with Count from photo, "
                "confirm the full set (0 missing), then check in."
            ),
        )
    canonical_id, samples, learned_count = result
    return LearnFromPhotoResult(
        toy_id=canonical_id,
        learn_samples=samples,
        learned_piece_count=learned_count,
        message=(
            f"Learned from photo ({samples} sample{'s' if samples != 1 else ''}). "
            "Reference and future counts for this toy will improve."
        ),
    )
