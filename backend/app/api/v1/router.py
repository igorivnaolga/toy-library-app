from fastapi import APIRouter

from app.api.v1.endpoints.admin import router as admin_router
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.bookings import router as bookings_router
from app.api.v1.endpoints.categories import router as categories_router
from app.api.v1.endpoints.health import router as health_router
from app.api.v1.endpoints.loans import router as loans_router
from app.api.v1.endpoints.toys import router as toys_router

api_router = APIRouter()
api_router.include_router(health_router, tags=["health"])
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(admin_router, prefix="/admin", tags=["admin"])
api_router.include_router(bookings_router, prefix="/bookings", tags=["bookings"])
api_router.include_router(loans_router, prefix="/loans", tags=["loans"])
api_router.include_router(toys_router, prefix="/toys", tags=["toys"])
api_router.include_router(categories_router, prefix="/categories", tags=["categories"])
