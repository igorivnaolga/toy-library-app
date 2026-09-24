# Build context: repo root (Railway root directory unset). Prefer backend/ as the
# root directory with backend/Dockerfile. Generated from backend/Dockerfile with a
# backend/ prefix on COPY sources; CI fails if the two drift.
FROM python:3.12-slim

WORKDIR /app

# OpenCV headless + common numeric libs used by toy CV helpers.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements-prod.txt backend/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements-prod.txt

# Unprivileged runtime user; only data/ (CV learning samples) is writable.
RUN useradd --system --uid 10001 --home-dir /app --shell /usr/sbin/nologin app \
    && mkdir -p /app/data \
    && chown app:app /app/data

COPY backend/app ./app
COPY backend/export_imgs ./export_imgs
# Migrations ship in the image so `alembic upgrade head` can run as a one-off job.
COPY backend/alembic.ini ./
COPY backend/migrations ./migrations

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD python -c "import os, urllib.request; p=os.environ.get('PORT','8000'); urllib.request.urlopen(f'http://127.0.0.1:{p}/api/v1/health')" || exit 1

CMD ["sh", "-c", "gunicorn app.main:app -k uvicorn.workers.UvicornWorker -b 0.0.0.0:${PORT:-8000} --workers 1 --timeout 120"]
