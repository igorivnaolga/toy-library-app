from app.services.pieces_from_setls import (
    aggregate_piece_lines_for_toy,
    aggregate_pieces_rows,
    format_piece_line,
    parse_piece_inventory_json,
    resolve_piece_lines_for_toy,
    serialize_piece_inventory,
    totals_from_piece_lines,
    ToyPieceLine,
)


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


def test_aggregate_piece_lines_for_toy() -> None:
    rows = [
        {
            "Toy ID": "100",
            "Name": "H",
            "Quantity": "2",
            "Soft deleted?": "",
        },
        {
            "Toy ID": "100",
            "Name": "H",
            "Quantity": "1",
            "Soft deleted?": "Yes",
        },
        {
            "Toy ID": "100",
            "Name": "A",
            "Quantity": "1",
            "Soft deleted?": "",
        },
    ]
    lines = aggregate_piece_lines_for_toy(rows, "100")
    assert len(lines) == 2
    h = next(line for line in lines if line.name == "H")
    assert h.quantity == 3
    assert h.missing == 1
    assert format_piece_line(h) == "3 H"


def test_format_piece_line_without_missing() -> None:
    assert format_piece_line(ToyPieceLine(name="A", quantity=1)) == "1 A"


def test_piece_inventory_round_trip() -> None:
    lines = [
        ToyPieceLine(name="H", quantity=2, missing=1),
        ToyPieceLine(name="A", quantity=1, missing=0),
    ]
    raw = serialize_piece_inventory(lines)
    parsed = parse_piece_inventory_json(raw)
    assert parsed is not None
    assert len(parsed) == 2
    assert totals_from_piece_lines(parsed) == (3, 1)


def test_resolve_piece_lines_prefers_db_inventory() -> None:
    stored = serialize_piece_inventory([ToyPieceLine(name="Custom", quantity=4)])
    lines = resolve_piece_lines_for_toy("100", piece_inventory=stored)
    assert len(lines) == 1
    assert lines[0].name == "Custom"
    assert lines[0].quantity == 4
