from fastapi import APIRouter

router = APIRouter()


@router.get("")
def list_categories() -> dict[str, list]:
    return {"data": []}
