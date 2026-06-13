"""
Toy catalog HTTP endpoints.

These endpoints are intentionally thin: validation/pagination lives here, while
data access + DB/CSV switching happens in repositories/services.
"""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import FileResponse, RedirectResponse

from app.core.auth_deps import get_optional_principal, require_roles
from app.core.roles import Role
from app.repositories.toy_repo import get_toy_piece_inventory_raw
from app.schemas.principal import Principal
from app.schemas.toy import (
    ToyOut,
    ToyPieceLineOut,
    ToyPiecesUpdate,
    ToysListMeta,
    ToysListResponse,
    ToysMetaOut,
)
from app.services.pieces_from_setls import resolve_piece_lines_for_toy
from app.services.toy_photo import (
    guess_media_type,
    resolve_toy_photo_path,
    resolve_toy_photo_public_url,
)
from app.services.toy_service import (
    get_toy_service,
    get_toys_meta_service,
    list_toys_service,
    update_toy_pieces_service,
)

router = APIRouter()


@router.get("/{toy_id}/photo", response_model=None)
def get_toy_photo(toy_id: str) -> FileResponse | RedirectResponse:
    """Serve the toy image from Supabase Storage or local ``TOY_IMAGES_DIR``."""
    public_url = resolve_toy_photo_public_url(toy_id)
    if public_url is not None:
        return RedirectResponse(url=public_url, status_code=307)

    path = resolve_toy_photo_path(toy_id)
    if path is None:
        raise HTTPException(status_code=404, detail="Toy photo not found")
    return FileResponse(path, media_type=guess_media_type(path))


@router.get("")
def list_toys(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    availability: Literal[
        "available", "on_loan", "reserved", "unavailable", "unknown"
    ]
    | None = None,
) -> ToysListResponse:
    # `list_toys_service` returns (page items, total matching rows before pagination).
    items, total = list_toys_service(
        page=page,
        limit=limit,
        q=q,
        category=category,
        age_range=age_range,
        status=status,
        availability=availability,
    )
    return ToysListResponse(
        data=items,
        meta=ToysListMeta(
            page=page,
            limit=limit,
            total=total,
            # Classic pagination: if we've shown `page * limit` items and there are more, there's a next page.
            has_next=page * limit < total,
        ),
    )


@router.get("/meta", response_model=ToysMetaOut)
def toys_meta() -> ToysMetaOut:
    """Distinct ``age_range`` values from the current dataset (Postgres or CSV fallback)."""
    return get_toys_meta_service()


def _staff_can_view_piece_lines(principal: Principal | None) -> bool:
    return principal is not None and principal.role in {Role.ADMIN, Role.VOLUNTEER}


@router.get("/{toy_id}", response_model=ToyOut)
def get_toy(
    toy_id: str,
    principal: Principal | None = Depends(get_optional_principal),
) -> ToyOut:
    toy = get_toy_service(toy_id)
    if not toy:
        raise HTTPException(status_code=404, detail="Toy not found")
    if not _staff_can_view_piece_lines(principal):
        return toy
    inventory = get_toy_piece_inventory_raw(toy_id)
    lines = resolve_piece_lines_for_toy(toy_id, piece_inventory=inventory)
    if not lines:
        return toy
    return toy.model_copy(
        update={
            "piece_lines": [
                ToyPieceLineOut(
                    name=line.name,
                    quantity=line.quantity,
                    missing=line.missing,
                )
                for line in lines
            ]
        }
    )


_require_staff = require_roles(Role.VOLUNTEER)


@router.patch("/{toy_id}/pieces", response_model=ToyOut)
def update_toy_pieces(
    toy_id: str,
    body: ToyPiecesUpdate,
    _: Principal = Depends(_require_staff),
) -> ToyOut:
    """Update piece inventory (admin or volunteer; no on-duty check)."""
    payload = body.model_dump(exclude_unset=True)
    if not payload:
        raise HTTPException(status_code=422, detail="No fields to update.")
    updated = update_toy_pieces_service(
        toy_id,
        total_pieces=payload.get("total_pieces"),
        missing_pieces=payload.get("missing_pieces"),
        piece_lines=body.piece_lines,
    )
    if updated is None:
        raise HTTPException(
            status_code=404,
            detail="Toy not found or catalog is not loaded in the database yet.",
        )
    inventory = get_toy_piece_inventory_raw(toy_id)
    lines = resolve_piece_lines_for_toy(toy_id, piece_inventory=inventory)
    if not lines:
        return updated
    return updated.model_copy(
        update={
            "piece_lines": [
                ToyPieceLineOut(
                    name=line.name,
                    quantity=line.quantity,
                    missing=line.missing,
                )
                for line in lines
            ]
        }
    )
