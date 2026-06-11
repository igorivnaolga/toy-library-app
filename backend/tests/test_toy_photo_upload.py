import pytest

from app.services.toy_photo_upload import _extension_for_upload


def test_extension_for_upload_jpeg_content_type() -> None:
    assert _extension_for_upload("image/jpeg", b"\xff\xd8\xff") == ".jpg"


def test_extension_for_upload_png_magic() -> None:
    assert _extension_for_upload(None, b"\x89PNG\r\n\x1a\n") == ".png"


def test_extension_for_upload_rejects_unknown() -> None:
    with pytest.raises(ValueError, match="Unsupported"):
        _extension_for_upload("text/plain", b"hello")
