from fastapi import APIRouter

from app.repositories.category_repo import list_categories as list_categories_repo
from app.schemas.category import CategoriesListResponse

router = APIRouter()


@router.get("")
def list_categories() -> CategoriesListResponse:
    return CategoriesListResponse(data=list_categories_repo())
