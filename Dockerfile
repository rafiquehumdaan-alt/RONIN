# Stage 1 - Install RONIN's Python dependencies
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .

RUN python -m venv /opt/venv
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# Stage 2 - Run RONIN
FROM python:3.12-slim AS runtime

ENV PATH="/opt/venv/bin:$PATH"
ENV PORT=80

WORKDIR /app

# Create a non-root user
RUN useradd --system --create-home ronin

# Copy dependencies from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy RONIN
COPY --chown=ronin:ronin app/ ./app/
COPY --chown=ronin:ronin run.py .

USER ronin

EXPOSE 80

CMD ["gunicorn", "--bind", "0.0.0.0:80", "--workers", "2", "run:app"]
