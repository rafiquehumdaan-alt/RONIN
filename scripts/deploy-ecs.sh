#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=ronin-cluster
SERVICE_NAME=ronin-service
ECR_REPOSITORY_URI="${1:?ECR repository URI is required}"
EXPECTED_IMAGE="$ECR_REPOSITORY_URI:latest"
EXPECTED_DIGEST="${2:?Image digest is required}"

CLUSTER_DETAILS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME")

if jq -e '(.clusters | length) == 0 and (.failures | length) == 1 and .failures[0].reason == "MISSING"' \
  <<< "$CLUSTER_DETAILS" >/dev/null; then
  echo "Image pushed. Run Terraform apply to create the ECS service."
  exit 0
fi

jq -e '.clusters[0].status == "ACTIVE"' <<< "$CLUSTER_DETAILS" >/dev/null

SERVICE_DETAILS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME")
if jq -e '(.services | length) == 0 and (.failures | length) == 1 and .failures[0].reason == "MISSING"' \
  <<< "$SERVICE_DETAILS" >/dev/null; then
  echo "Image pushed. Run Terraform apply to create the ECS service."
  exit 0
fi

TASK_DEFINITION=$(jq -er '.services[0] | select(.status == "ACTIVE").taskDefinition' <<< "$SERVICE_DETAILS")
TASK_DETAILS=$(aws ecs describe-task-definition --task-definition "$TASK_DEFINITION")
CURRENT_IMAGE=$(jq -er '.taskDefinition.containerDefinitions[] | select(.name == "ronin").image' <<< "$TASK_DETAILS")

if [ "$CURRENT_IMAGE" != "$EXPECTED_IMAGE" ]; then
  echo "ECS task uses $CURRENT_IMAGE. Run Terraform apply to update the task definition." >&2
  exit 1
fi

CURRENT_DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPOSITORY_URI##*/}" \
  --image-ids imageTag=latest \
  --query 'imageDetails[0].imageDigest' \
  --output text)

if [ "$CURRENT_DIGEST" != "$EXPECTED_DIGEST" ]; then
  echo "The latest ECR tag does not match the image pushed by this run." >&2
  exit 1
fi

echo "Deploying $EXPECTED_IMAGE ($EXPECTED_DIGEST) to $SERVICE_NAME..."

SERVICE_UPDATE=$(aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force-new-deployment)
DEPLOYMENT_ID=$(jq -er '.service.deployments[] | select(.status == "PRIMARY").id' <<< "$SERVICE_UPDATE")

echo "Waiting for ECS rollout..."

aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

SERVICE_DETAILS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME")
jq -e --arg deployment "$DEPLOYMENT_ID" '
  .services[0].deployments[] |
  select(.id == $deployment and .status == "PRIMARY" and .rolloutState == "COMPLETED")
' <<< "$SERVICE_DETAILS"

echo "Verifying the image digest on running ECS tasks..."

TASK_LIST=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING)
TASK_ARNS=$(jq -er '.taskArns | select(length > 0)[]' <<< "$TASK_LIST")
mapfile -t TASKS <<< "$TASK_ARNS"

RUNNING_TASKS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "${TASKS[@]}")
jq -e --arg digest "$EXPECTED_DIGEST" --argjson count "${#TASKS[@]}" '
  (.failures | length) == 0 and
  (.tasks | length) == $count and
  all(.tasks[]; .lastStatus == "RUNNING" and
    any(.containers[]; .name == "ronin" and .imageDigest == $digest))
' <<< "$RUNNING_TASKS" >/dev/null

echo "Verifying public health..."

bash scripts/verify-app-health.sh https://ronin.humdaan.co.uk/health 15

echo "RONIN deployment successful."
