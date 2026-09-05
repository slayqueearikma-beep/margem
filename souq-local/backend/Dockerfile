FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN groupadd --system margem && useradd --system --gid margem --create-home margem \
    && apt-get update \
    && apt-get install -y --no-install-recommends gosu \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt backend/requirements-telemetry.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements-telemetry.txt

COPY backend/app ./app
COPY backend/scripts ./scripts
COPY backend/alembic ./alembic
COPY backend/alembic.ini .
COPY backend/static ./static
COPY admin-dashboard /admin-dashboard

RUN chmod +x /app/scripts/entrypoint.sh /app/scripts/docker-entrypoint-wrapper.sh \
    && chown -R margem:margem /app /admin-dashboard

ENV ADMIN_DASHBOARD_DIR=/admin-dashboard

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/ready')"

ENTRYPOINT ["/app/scripts/docker-entrypoint-wrapper.sh"]
