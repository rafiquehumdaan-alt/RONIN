FROM python:3.12-slim AS builder

WORKDIR /build
COPY requirements.txt .
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.12-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH" \
    PORT=8080
WORKDIR /app
RUN useradd --system --create-home ronin

COPY --from=builder /opt/venv /opt/venv
COPY --chown=ronin:ronin app/ ./app/
COPY --chown=ronin:ronin run.py .

USER ronin
EXPOSE 8080
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8080", "run:app"]
