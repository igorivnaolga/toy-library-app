# Railway fallback when the service root directory is the repo root (not backend/).
# Prefer setting Railway Root Directory to backend/ and using backend/Dockerfile.
FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libglib2.0-0 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements-prod.txt backend/requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements-prod.txt

COPY backend/app ./app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CREATE_TABLES_ON_STARTUP=false

EXPOSE 8000

CMD ["sh", "-c", "gunicorn app.main:app -k uvicorn.workers.UvicornWorker -b 0.0.0.0:${PORT:-8000} --workers 1 --timeout 120"]
