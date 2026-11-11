#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${1:?Local image tag is required}"

echo "Starting $LOCAL_IMAGE for the health check..."
CONTAINER_ID=$(docker run --detach --publish 127.0.0.1::8080 "$LOCAL_IMAGE")
trap 'docker rm --force "$CONTAINER_ID" >/dev/null' EXIT

CONTAINER_ADDRESS=$(docker port "$CONTAINER_ID" 8080/tcp)
if ! bash scripts/verify-app-health.sh "http://$CONTAINER_ADDRESS/health" 2; then
  docker logs "$CONTAINER_ID"
  exit 1
fi
