#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME=""
ALIAS_NAME="stable"
PREVIOUS_VERSION=""
NEW_VERSION=""
CANARY_PERCENT="0.10"
LATENCY_THRESHOLD_MS="130"
ERROR_RATE_THRESHOLD="0.02"
WINDOW_MINUTES="15"
POLL_INTERVAL_SECONDS="60"
AWS_REGION="us-east-1"

print_cloudwatch_refs() {
  echo "CloudWatch refs:"
  echo "- Console: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}"
  echo "- Canary metric target: AWS/Lambda Resource=${FUNCTION_NAME}:${NEW_VERSION}"
  echo "- Metrics checked: Duration p99, Errors Sum, Invocations Sum"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --function-name) FUNCTION_NAME="$2"; shift 2 ;;
    --alias-name) ALIAS_NAME="$2"; shift 2 ;;
    --previous-version) PREVIOUS_VERSION="$2"; shift 2 ;;
    --new-version) NEW_VERSION="$2"; shift 2 ;;
    --canary-percent) CANARY_PERCENT="$2"; shift 2 ;;
    --latency-threshold-ms) LATENCY_THRESHOLD_MS="$2"; shift 2 ;;
    --error-rate-threshold) ERROR_RATE_THRESHOLD="$2"; shift 2 ;;
    --window-minutes) WINDOW_MINUTES="$2"; shift 2 ;;
    --poll-interval-seconds) POLL_INTERVAL_SECONDS="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    *) echo "unknown argument: $1"; exit 2 ;;
  esac
done

if [[ -z "$FUNCTION_NAME" || -z "$PREVIOUS_VERSION" || -z "$NEW_VERSION" ]]; then
  echo "missing required args"
  exit 2
fi

if [[ "$PREVIOUS_VERSION" == "$NEW_VERSION" ]]; then
  echo "same version already active; skipping canary"
  exit 0
fi

rollback() {
  print_cloudwatch_refs
  ./scripts/lambda-rollback.sh "$FUNCTION_NAME" "$ALIAS_NAME" "$PREVIOUS_VERSION" "$AWS_REGION"
}

# shift 10% to the new version while keeping stable traffic on previous version
aws lambda update-alias \
  --region "$AWS_REGION" \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --function-version "$PREVIOUS_VERSION" \
  --routing-config "AdditionalVersionWeights={$NEW_VERSION=$CANARY_PERCENT}"

END=$(( $(date +%s) + WINDOW_MINUTES * 60 ))
while [[ $(date +%s) -lt $END ]]; do
  sleep "$POLL_INTERVAL_SECONDS"

  START_TIME=$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%S)
  END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)

  P99=$(aws cloudwatch get-metric-statistics \
    --region "$AWS_REGION" \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" Name=Resource,Value="$FUNCTION_NAME:$NEW_VERSION" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --extended-statistics p99 \
    --query 'max_by(Datapoints, &Timestamp).ExtendedStatistics.p99' \
    --output text)

  ERRORS=$(aws cloudwatch get-metric-statistics \
    --region "$AWS_REGION" \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" Name=Resource,Value="$FUNCTION_NAME:$NEW_VERSION" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Sum \
    --query 'sum(Datapoints[].Sum)' \
    --output text)

  INVOCATIONS=$(aws cloudwatch get-metric-statistics \
    --region "$AWS_REGION" \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value="$FUNCTION_NAME" Name=Resource,Value="$FUNCTION_NAME:$NEW_VERSION" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Sum \
    --query 'sum(Datapoints[].Sum)' \
    --output text)

  [[ "$P99" == "None" || -z "$P99" ]] && P99=0
  [[ "$ERRORS" == "None" || -z "$ERRORS" ]] && ERRORS=0
  [[ "$INVOCATIONS" == "None" || -z "$INVOCATIONS" ]] && INVOCATIONS=0

  echo "canary v$NEW_VERSION | p99=${P99}ms errors=${ERRORS} invocations=${INVOCATIONS}"

  if awk "BEGIN {exit !($P99 > $LATENCY_THRESHOLD_MS)}"; then
    echo "canary unhealthy: latency ${P99}ms"
    rollback
    exit 1
  fi

  if awk "BEGIN {exit !($INVOCATIONS > 0 && $ERRORS / $INVOCATIONS > $ERROR_RATE_THRESHOLD)}"; then
    echo "canary unhealthy: error rate above threshold"
    rollback
    exit 1
  fi
done

# promote to 100%
aws lambda update-alias \
  --region "$AWS_REGION" \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --function-version "$NEW_VERSION" \
  --routing-config "AdditionalVersionWeights={}"

echo "canary healthy and promoted to 100%"
print_cloudwatch_refs
