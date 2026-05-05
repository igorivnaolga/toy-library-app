"""
Toy catalog HTTP endpoints.

These endpoints are intentionally thin: validation/pagination lives here, while
data access + DB/CSV switching happens in repositories/services.
"""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse

from app.schemas.toy import ToyOut, ToysListMeta, ToysListResponse
from app.services.toy_photo import guess_media_type, resolve_toy_photo_path
from app.services.toy_service import get_toy_service, list_toys_service

router = APIRouter()


@router.get("/{toy_id}/photo")
def get_toy_photo(toy_id: str) -> FileResponse:
    """Serve the image file referenced by `ToyOut.photo_file` when `TOY_IMAGES_DIR` / repo folder exists."""
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
) -> ToysListResponse:
    # `list_toys_service` returns (page items, total matching rows before pagination).
    items, total = list_toys_service(
        page=page,
        limit=limit,
        q=q,
        category=category,
        age_range=age_range,
        status=status,
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


@router.get("/{toy_id}", response_model=ToyOut)
def get_toy(toy_id: str) -> ToyOut:
    toy = get_toy_service(toy_id)
    if not toy:
        raise HTTPException(status_code=404, detail="Toy not found")
    return toy
