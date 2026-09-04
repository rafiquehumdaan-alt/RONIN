# Stage 1: BUILDER

FROM python:3.12-slim AS builder
# Start with small linux image that has python installed. Name it "builder" so we can reference it later.
WORKDIR /build
# Similar to cd, this sets the working directory for the next commands. If the directory doesn't exist, it will be created.
COPY requirements.txt .
# Copy requirements.txt into the working directory (/build)
RUN python -m venv /opt/venv
# Create a virtual environment to store RONIN's Python dependencies
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt
# Install RONIN's dependencies into the virtual environment



# Stage 2 — Runtime

FROM python:3.12-slim AS runtime
# Start again with a fresh small Python 3.12 environment and call this one "runtime"
ENV PATH="/opt/venv/bin:$PATH"
# Make the virtual environment's Python tools available as normal commands
ENV PORT=8080
# Set RONIN's application port to 8080
WORKDIR /app
# Create /app and use it as RONIN's working directory
RUN useradd --system --create-home ronin
# Create a non-root user called ronin for better security
COPY --from=builder /opt/venv /opt/venv
# Copy the installed dependencies from the builder stage
COPY --chown=ronin:ronin app/ ./app/
# Copy RONIN's application files and give the ronin user ownership
COPY --chown=ronin:ronin run.py .
# Copy RONIN's startup file and give the ronin user ownership
USER ronin
# Run RONIN as the non-root ronin user
EXPOSE 8080
# RONIN listens on port 8080
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8080", "run:app"]
# Start RONIN with Gunicorn on port 8080



# Multi-stage keeps the final image clean by leaving build-only files like requirements.txt behind.