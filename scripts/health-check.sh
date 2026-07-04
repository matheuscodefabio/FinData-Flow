#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME="${FUNCTION_NAME:-findata-ingestor-prod}"
ALIAS_NAME="${ALIAS_NAME:-stable}"
DLQ_NAME="${DLQ_NAME:-findata-processor-dlq-prod}"
ECS_CLUSTER_NAME="${ECS_CLUSTER_NAME:-findata-processor-prod}"
AWS_REGION="${AWS_REGION:-us-east-1}"
P99_THRESHOLD_MS="${P99_THRESHOLD_MS:-130}"
ECS_STOPPED_THRESHOLD="${ECS_STOPPED_THRESHOLD:-2}"

START_TIME=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S)
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

P99=$(aws cloudwatch get-metric-statistics \
  --region "$AWS_REGION" \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value="$FUNCTION_NAME" Name=Resource,Value="$FUNCTION_NAME:$ALIAS_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 300 \
  --extended-statistics p99 \
  --query 'max_by(Datapoints, &Timestamp).ExtendedStatistics.p99' \
  --output text)

[[ "$P99" == "None" || -z "$P99" ]] && P99=0

echo "Lambda P99 Latency: ${P99}ms"
if awk "BEGIN {exit !($P99 > $P99_THRESHOLD_MS)}"; then
  echo "P99 latency ABOVE threshold (${P99_THRESHOLD_MS}ms)"
  exit 1
fi

DLQ_URL=$(aws sqs get-queue-url \
  --region "$AWS_REGION" \
  --queue-name "$DLQ_NAME" \
  --query 'QueueUrl' \
  --output text)

DLQ_DEPTH=$(aws sqs get-queue-attributes \
  --region "$AWS_REGION" \
  --queue-url "$DLQ_URL" \
  --attribute-names ApproximateNumberOfMessagesVisible \
  --query 'Attributes.ApproximateNumberOfMessagesVisible' \
  --output text)

[[ "$DLQ_DEPTH" == "None" || -z "$DLQ_DEPTH" ]] && DLQ_DEPTH=0

echo "DLQ Depth: $DLQ_DEPTH messages"
if (( DLQ_DEPTH > 0 )); then
  echo "DLQ contem mensagens — investigar falhas"
  exit 1
fi

FAILED_TASKS=$(aws ecs list-tasks \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER_NAME" \
  --desired-status STOPPED \
  --query 'taskArns | length(@)' \
  --output text)

[[ "$FAILED_TASKS" == "None" || -z "$FAILED_TASKS" ]] && FAILED_TASKS=0

echo "Failed ECS tasks (stopped): $FAILED_TASKS"
if (( FAILED_TASKS > ECS_STOPPED_THRESHOLD )); then
  echo "ECS stopped tasks acima do threshold (${ECS_STOPPED_THRESHOLD})"
  exit 1
fi

echo "health-check ok"
