#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="${1:?Local image tag is required}"
ECR_REPOSITORY_URI="${2:?ECR repository URI is required}"
IMAGE_TAG="${3:?Image tag is required}"

for IMAGE_URI in "$ECR_REPOSITORY_URI:$IMAGE_TAG" "$ECR_REPOSITORY_URI:latest"; do
  echo "Tagging Docker image as $IMAGE_URI..."
  docker tag "$LOCAL_IMAGE" "$IMAGE_URI"

  echo "Pushing Docker image to ECR..."
  docker push "$IMAGE_URI"

  echo "Image pushed: $IMAGE_URI"
done

# Tag the Docker image and push it to Amazon ECR.