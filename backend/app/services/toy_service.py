from app.repositories.toy_repo import distinct_age_ranges, get_toy_by_id, list_toys
from app.schemas.toy import ToyOut, ToysMetaOut


def list_toys_service(
    page: int = 1,
    limit: int = 20,
    q: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    availability: str | None = None,
) -> tuple[list[ToyOut], int]:
    return list_toys(
        page=page,
        limit=limit,
        q=q,
        category=category,
        age_range=age_range,
        status=status,
        availability=availability,
    )


def get_toy_service(toy_id: str) -> ToyOut | None:
    return get_toy_by_id(toy_id)


def get_toys_meta_service() -> ToysMetaOut:
    return ToysMetaOut(age_ranges=distinct_age_ranges())
