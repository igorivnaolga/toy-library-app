from app.services.pieces_from_setls import aggregate_pieces_rows


def test_aggregate_pieces_rows() -> None:
    rows = [
        {"Toy ID": "100", "Quantity": "2", "Soft deleted?": "", "Toy name": "Duplo"},
        {"Toy ID": "100", "Quantity": "1", "Soft deleted?": "Yes", "Toy name": "Duplo"},
        {"Toy ID": "903", "Quantity": "1", "Soft deleted?": "", "Toy name": "Dress Up"},
        {"Toy ID": "903", "Quantity": "1", "Soft deleted?": "Yes", "Toy name": "Dress Up"},
    ]
    summary = aggregate_pieces_rows(rows)
    assert summary["100"] == (3, 1)
    assert summary["903"] == (2, 1)
