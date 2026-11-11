#!/usr/bin/env bash
set -euo pipefail

HEALTH_URL="${1:?Health URL is required}"
RETRY_DELAY="${2:?Retry delay is required}"

for attempt in {1..12}; do
  if RESPONSE=$(curl --fail --silent --show-error --max-time 10 "$HEALTH_URL") &&
    jq -e '.status == "ok"' <<< "$RESPONSE" >/dev/null; then
    echo "Health check passed for $HEALTH_URL."
    exit 0
  fi

  echo "Health check attempt $attempt failed for $HEALTH_URL" >&2

  if [ "$attempt" -lt 12 ]; then
    sleep "$RETRY_DELAY"
  fi
done

echo "Timed out waiting for $HEALTH_URL." >&2
exit 1
