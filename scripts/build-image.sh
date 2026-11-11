#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:?Local image tag is required}"

echo "Building Docker image $IMAGE_TAG..."
docker build --provenance=false -t "$IMAGE_TAG" ./app
