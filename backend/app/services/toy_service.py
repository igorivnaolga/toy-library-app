from app.repositories.toy_repo import distinct_age_ranges, distinct_manufacturers, get_toy_by_id, list_toys
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
    return ToysMetaOut(
        age_ranges=distinct_age_ranges(),
        manufacturers=distinct_manufacturers(),
    )


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


def delete_toy_service(toy_id: str) -> bool | None:
    from app.repositories.toy_repo import delete_toy_in_db

    try:
        return delete_toy_in_db(toy_id)
    except ValueError as e:
        from fastapi import HTTPException

        raise HTTPException(status_code=409, detail=str(e)) from e


def update_toy_pieces_service(
    toy_id: str,
    *,
    total_pieces: int | None = None,
    missing_pieces: int | None = None,
    piece_lines: list | None = None,
) -> ToyOut | None:
    from app.repositories.toy_repo import update_toy_pieces_in_db
    from app.services.pieces_from_setls import ToyPieceLine

    parsed_lines: list[ToyPieceLine] | None = None
    if piece_lines is not None:
        parsed_lines = [
            ToyPieceLine(
                name=line.name.strip(),
                quantity=line.quantity,
                missing=line.missing,
            )
            for line in piece_lines
        ]

    try:
        return update_toy_pieces_in_db(
            toy_id,
            total_pieces=total_pieces,
            missing_pieces=missing_pieces,
            piece_lines=parsed_lines,
        )
    except ValueError as e:
        from fastapi import HTTPException

        raise HTTPException(status_code=422, detail=str(e)) from e
