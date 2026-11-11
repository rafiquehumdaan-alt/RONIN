#!/usr/bin/env bash
set -euo pipefail

if RESULT=$(aws ecr describe-images --repository-name ronin --image-ids imageTag=latest 2>&1); then
  echo "Found the RONIN image in ECR."
  echo "exists=true" >> "$GITHUB_OUTPUT"
elif [[ "$RESULT" == *"(RepositoryNotFoundException)"* || "$RESULT" == *"(ImageNotFoundException)"* ]]; then
  echo "ECR has no RONIN image yet. Terraform will apply only the ECR repository when requested."
  echo "exists=false" >> "$GITHUB_OUTPUT"
else
  echo "$RESULT" >&2
  exit 1
fi
