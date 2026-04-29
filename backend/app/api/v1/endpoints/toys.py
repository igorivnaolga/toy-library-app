from fastapi import APIRouter

router = APIRouter()


@router.get("")
def list_toys() -> dict[str, list]:
    return {"data": []}


@router.get("/{toy_id}")
def get_toy(toy_id: str) -> dict[str, str]:
    return {"toy_id": toy_id}
