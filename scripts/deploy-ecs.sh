#!/usr/bin/env bash
set -euo pipefail

image_tag="${1:?Image tag is required}"
cluster=ronin-cluster
service=ronin-service
scaling_target=(
  --service-namespace ecs
  --scalable-dimension ecs:service:DesiredCount
)

expected_digest=$(aws ecr describe-images \
  --repository-name ronin \
  --image-ids "imageTag=$image_tag" \
  --query 'imageDetails[0].imageDigest' --output text)

minimum=$(aws application-autoscaling describe-scalable-targets \
  "${scaling_target[@]}" \
  --resource-ids "service/$cluster/$service" \
  --query 'ScalableTargets[0].MinCapacity' --output text)

desired=$(aws ecs describe-services --cluster "$cluster" --services "$service" \
  --query 'services[0].desiredCount' --output text)

capacity=()
if [[ "$minimum" == 0 && ( "$desired" == 0 || "$desired" == 1 ) ]]; then
  capacity=(--desired-count 2)
fi

echo "Starting ECS rollout for $image_tag"
aws ecs update-service --cluster "$cluster" --service "$service" \
  --force-new-deployment "${capacity[@]}" >/dev/null

aws ecs wait services-stable --cluster "$cluster" --services "$service"

task_arns=$(aws ecs list-tasks --cluster "$cluster" --service-name "$service" \
  --desired-status RUNNING --query 'taskArns[]' --output text)
read -r -a tasks <<< "$task_arns"

if (( ${#tasks[@]} < 2 )); then
  echo "Expected at least two RONIN tasks after rollout." >&2
  exit 1
fi

details=$(aws ecs describe-tasks --cluster "$cluster" --tasks "${tasks[@]}")
if ! jq -e --arg digest "$expected_digest" --argjson count "${#tasks[@]}" '
  (.failures | length) == 0 and
  (.tasks | length) == $count and
  all(.tasks[]; .lastStatus == "RUNNING" and
    any(.containers[]; .name == "ronin" and .imageDigest == $digest))
' <<< "$details" >/dev/null; then
  echo "Expected every running RONIN task to use $expected_digest." >&2
  jq '.tasks[] | {taskArn, lastStatus, containers: [.containers[] | {name, imageDigest}]}' \
    <<< "$details" >&2
  exit 1
fi

bash scripts/verify-app-health.sh https://ronin.humdaan.co.uk/health 15

if [[ "$minimum" == 0 ]]; then
  aws application-autoscaling register-scalable-target \
    "${scaling_target[@]}" \
    --resource-id "service/$cluster/$service" \
    --min-capacity 2
fi