# Multi-stage Dockerfile that builds a lightweight RONIN image and runs the application securely as a non-root user.

# Stage 1 - Build the Python environment and install RONIN's runtime dependencies.
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy the dependency list into the build stage.
COPY requirements.txt .

# Create a virtual environment and install only the production dependencies.
RUN python -m venv /opt/venv
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# Stage 2 - Create the final lightweight runtime image used to run RONIN.
FROM python:3.12-slim AS runtime

# Use the virtual environment copied from the builder stage.
ENV PATH="/opt/venv/bin:$PATH"

# RONIN listens internally on port 8080.
ENV PORT=8080

WORKDIR /app

# Create a dedicated non-root user to reduce the container's privileges.
RUN useradd --system --create-home ronin

# Copy the installed dependencies from the builder stage.
COPY --from=builder /opt/venv /opt/venv

# Copy the RONIN application into the runtime image and give the ronin user ownership.
COPY --chown=ronin:ronin app/ ./app/
COPY --chown=ronin:ronin run.py .

# Run the application as the non-root ronin user rather than root.
USER ronin

# Document the port used by the application inside the container.
EXPOSE 8080

# Start RONIN using Gunicorn with two worker processes.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "run:app"]