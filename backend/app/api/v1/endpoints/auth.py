"""Auth introspection for Supabase-signed clients."""

from fastapi import APIRouter, Depends

from app.core.auth_deps import get_current_principal
from app.schemas.principal import MeOut, Principal

router = APIRouter()


@router.get("/me", response_model=MeOut)
def read_me(principal: Principal = Depends(get_current_principal)) -> MeOut:
    """Return the current user id, email (from JWT), and **app role** from `profiles`."""
    return MeOut(
        user_id=principal.id,
        email=principal.email,
        role=principal.role,
        full_name=principal.full_name,
    )
