from fastapi import APIRouter, HTTPException, Query

from app.schemas.toy import ToyOut, ToysListMeta, ToysListResponse
from app.services.toy_service import get_toy_service, list_toys_service

router = APIRouter()


@router.get("")
def list_toys(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
) -> ToysListResponse:
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
            has_next=page * limit < total,
        ),
    )


@router.get("/{toy_id}")
def get_toy(toy_id: str) -> ToyOut:
    toy = get_toy_service(toy_id)
    if not toy:
        raise HTTPException(status_code=404, detail="Toy not found")
    return toy
