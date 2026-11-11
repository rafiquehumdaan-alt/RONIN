#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME=ronin-cluster
SERVICE_NAME=ronin-service
SCALING_RESOURCE="service/$CLUSTER_NAME/$SERVICE_NAME"
LOCAL_IMAGE="${1:?Local image tag is required}"
ECR_REPOSITORY_URI="${2:?ECR repository URI is required}"
IMAGE_TAG="${3:?Image tag is required}"
REPOSITORY_NAME="${ECR_REPOSITORY_URI##*/}"
EXPECTED_IMAGE="$ECR_REPOSITORY_URI:latest"

CLUSTER_DETAILS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME")

if jq -e '(.clusters | length) == 0 and (.failures | length) == 1 and .failures[0].reason == "MISSING"' \
  <<< "$CLUSTER_DETAILS" >/dev/null; then
  echo "Run Terraform Apply first." >&2
  exit 1
fi

jq -e '.clusters[0].status == "ACTIVE"' <<< "$CLUSTER_DETAILS" >/dev/null

SERVICE_DETAILS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME")
if jq -e '
  .services[0].status == "INACTIVE" or
  ((.services | length) == 0 and (.failures | length) == 1 and .failures[0].reason == "MISSING")
' <<< "$SERVICE_DETAILS" >/dev/null; then
  echo "Run Terraform Apply first." >&2
  exit 1
fi

TASK_DEFINITION=$(jq -er '.services[0] | select(.status == "ACTIVE").taskDefinition' <<< "$SERVICE_DETAILS")
TASK_DETAILS=$(aws ecs describe-task-definition --task-definition "$TASK_DEFINITION")
CURRENT_IMAGE=$(jq -er '.taskDefinition.containerDefinitions[] | select(.name == "ronin").image' <<< "$TASK_DETAILS")

if [ "$CURRENT_IMAGE" != "$EXPECTED_IMAGE" ]; then
  echo "ECS task uses $CURRENT_IMAGE. Run Terraform Apply first." >&2
  exit 1
fi

DESIRED_COUNT=$(jq -er '.services[0].desiredCount | numbers' <<< "$SERVICE_DETAILS")
SCALING_TARGET=$(aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-ids "$SCALING_RESOURCE")
MIN_CAPACITY=$(jq -er '.ScalableTargets[0].MinCapacity | numbers' <<< "$SCALING_TARGET")

bash scripts/push-image-to-ecr.sh "$LOCAL_IMAGE" "$ECR_REPOSITORY_URI" "$IMAGE_TAG"

EXPECTED_DIGEST=$(aws ecr describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --image-ids "imageTag=$IMAGE_TAG" \
  --query 'imageDetails[0].imageDigest' \
  --output text)
CURRENT_DIGEST=$(aws ecr describe-images \
  --repository-name "$REPOSITORY_NAME" \
  --image-ids imageTag=latest \
  --query 'imageDetails[0].imageDigest' \
  --output text)

if [[ "$EXPECTED_DIGEST" != sha256:* || "$CURRENT_DIGEST" != "$EXPECTED_DIGEST" ]]; then
  echo "The latest ECR tag does not match the image pushed by this run." >&2
  exit 1
fi

echo "Deploying $EXPECTED_IMAGE ($EXPECTED_DIGEST) to $SERVICE_NAME..."

CAPACITY_ARGS=()
if [ "$MIN_CAPACITY" -eq 0 ] && [ "$DESIRED_COUNT" -lt 2 ]; then
  echo "Starting RONIN with two tasks..."
  CAPACITY_ARGS=(--desired-count 2)
fi

SERVICE_UPDATE=$(aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force-new-deployment "${CAPACITY_ARGS[@]}")
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

if [ "$MIN_CAPACITY" -eq 0 ]; then
  echo "Setting the ECS autoscaling minimum to two tasks..."

  aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id "$SCALING_RESOURCE" \
    --min-capacity 2
fi

echo "Verifying public health..."

bash scripts/verify-app-health.sh https://ronin.humdaan.co.uk/health 15

echo "RONIN deployment successful."
