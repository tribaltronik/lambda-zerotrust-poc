#!/usr/bin/env bash
set -euo pipefail
ENDPOINT="${AWS_ENDPOINT_URL:-http://localhost:4566}"
TIMEOUT="${1:-30}"
echo "Waiting for Floci at $ENDPOINT..."
for i in $(seq 1 "$TIMEOUT"); do
  if curl -sf "$ENDPOINT/_localstack/health" > /dev/null 2>&1; then
    echo "Floci ready after ${i}s"
    exit 0
  fi
  sleep 1
done
echo "Floci not ready after ${TIMEOUT}s"
exit 1
