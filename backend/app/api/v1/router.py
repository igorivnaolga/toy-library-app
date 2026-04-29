from fastapi import APIRouter

from app.api.v1.endpoints.categories import router as categories_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.toys import router as toys_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["health"])
api_router.include_router(toys_router, prefix="/toys", tags=["toys"])
api_router.include_router(categories_router, prefix="/categories", tags=["categories"])
