FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN groupadd --system margem && useradd --system --gid margem --create-home margem

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY scripts ./scripts
COPY alembic ./alembic
COPY alembic.ini .

RUN chmod +x /app/scripts/entrypoint.sh \
    && chown -R margem:margem /app

USER margem

EXPOSE 8000

ENTRYPOINT ["/app/scripts/entrypoint.sh"]
