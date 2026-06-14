"""Resize and compress catalog toy photos for faster mobile delivery."""

from __future__ import annotations

import io

from PIL import Image, ImageOps

MAX_LONG_EDGE_PX = 1200
JPEG_QUALITY = 82


def _to_rgb(img: Image.Image) -> Image.Image:
    if img.mode == "RGB":
        return img
    if img.mode in ("RGBA", "LA") or (
        img.mode == "P" and "transparency" in img.info
    ):
        rgba = img.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.split()[-1])
        return background
    return img.convert("RGB")


def _limit_long_edge(img: Image.Image, max_long_edge: int) -> Image.Image:
    width, height = img.size
    long_edge = max(width, height)
    if long_edge <= max_long_edge:
        return img
    scale = max_long_edge / long_edge
    new_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    return img.resize(new_size, Image.Resampling.LANCZOS)


def normalize_toy_photo_bytes(data: bytes) -> bytes:
    """
    Decode, apply EXIF orientation, cap the long edge, and emit optimized JPEG.

    Raises ``ValueError`` when the payload is empty or not a decodable image.
    """
    if not data:
        raise ValueError("Empty image upload.")

    try:
        with Image.open(io.BytesIO(data)) as opened:
            img = ImageOps.exif_transpose(opened)
            rgb = _limit_long_edge(_to_rgb(img), MAX_LONG_EDGE_PX)
            out = io.BytesIO()
            rgb.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            return out.getvalue()
    except OSError as exc:
        raise ValueError("Unsupported image format. Use JPEG, PNG, or WebP.") from exc
