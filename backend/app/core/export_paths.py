"""Resolve repo ``export_imgs/`` for local dev and Docker (/app/export_imgs)."""

from __future__ import annotations

from pathlib import Path


def export_imgs_dir() -> Path:
    """
    Local dev: ``backend/app/services/*.py`` → repo root ``export_imgs/``.

    Docker (``WORKDIR /app``, ``COPY app ./app``): ``/app/export_imgs/``.
    """
    here = Path(__file__).resolve()
    for depth in (3, 2):
        candidate = here.parents[depth] / "export_imgs"
        if candidate.is_dir():
            return candidate
    return here.parents[3] / "export_imgs"
