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


def create_toy_service(
    *,
    name: str,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = "In library",
    manufacturer: str | None = None,
    description: str | None = None,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    rental_price_cents: int | None = None,
) -> ToyOut | None:
    from app.repositories.toy_repo import create_toy_in_db

    try:
        return create_toy_in_db(
            name=name,
            category_label=category,
            age_range=age_range,
            status=status,
            manufacturer=manufacturer,
            description=description,
            total_pieces=total_pieces,
            missing_pieces=missing_pieces,
            rental_price_cents=rental_price_cents,
        )
    except ValueError as e:
        from fastapi import HTTPException

        raise HTTPException(status_code=422, detail=str(e)) from e


def update_toy_service(
    toy_id: str,
    *,
    name: str | None = None,
    category: str | None = None,
    age_range: str | None = None,
    status: str | None = None,
    manufacturer: str | None = None,
    description: str | None = None,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    rental_price_cents: int | None = None,
) -> ToyOut | None:
    from app.repositories.toy_repo import update_toy_in_db

    try:
        return update_toy_in_db(
            toy_id,
            name=name,
            category_label=category,
            age_range=age_range,
            status=status,
            manufacturer=manufacturer,
            description=description,
            total_pieces=total_pieces,
            missing_pieces=missing_pieces,
            rental_price_cents=rental_price_cents,
        )
    except ValueError as e:
        from fastapi import HTTPException

        raise HTTPException(status_code=422, detail=str(e)) from e


def update_toy_pieces_service(
    toy_id: str,
    *,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
) -> ToyOut | None:
    from app.repositories.toy_repo import update_toy_pieces_in_db

    try:
        return update_toy_pieces_in_db(
            toy_id,
            total_pieces=total_pieces,
            missing_pieces=missing_pieces,
        )
    except ValueError as e:
        from fastapi import HTTPException

        raise HTTPException(status_code=422, detail=str(e)) from e
