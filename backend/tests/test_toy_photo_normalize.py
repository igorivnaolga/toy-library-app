import io

import pytest
from PIL import Image

from app.services.toy_photo_normalize import MAX_LONG_EDGE_PX, normalize_toy_photo_bytes


def _jpeg_bytes(width: int, height: int, *, quality: int = 95) -> bytes:
    img = Image.new("RGB", (width, height), color=(200, 100, 50))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=quality)
    return buf.getvalue()


def _png_bytes(width: int, height: int) -> bytes:
    img = Image.new("RGBA", (width, height), color=(10, 20, 30, 128))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_normalize_toy_photo_bytes_empty_raises() -> None:
    with pytest.raises(ValueError, match="Empty"):
        normalize_toy_photo_bytes(b"")


def test_normalize_toy_photo_bytes_rejects_invalid() -> None:
    with pytest.raises(ValueError, match="Unsupported"):
        normalize_toy_photo_bytes(b"not-an-image")


def test_normalize_toy_photo_bytes_caps_long_edge() -> None:
    raw = _jpeg_bytes(2400, 1600)
    out = normalize_toy_photo_bytes(raw)
    with Image.open(io.BytesIO(out)) as img:
        assert max(img.size) == MAX_LONG_EDGE_PX
        assert img.format == "JPEG"


def test_normalize_toy_photo_bytes_converts_png_to_jpeg() -> None:
    raw = _png_bytes(400, 300)
    out = normalize_toy_photo_bytes(raw)
    assert out.startswith(b"\xff\xd8\xff")
    with Image.open(io.BytesIO(out)) as img:
        assert img.mode == "RGB"
        assert img.format == "JPEG"


def test_normalize_toy_photo_bytes_smaller_than_large_source() -> None:
    raw = _jpeg_bytes(2000, 1500, quality=95)
    out = normalize_toy_photo_bytes(raw)
    assert len(out) < len(raw)
