#!/usr/bin/env bash
set -euo pipefail

FUNCTION_NAME="${1:-}"
ALIAS_NAME="${2:-stable}"
TARGET_VERSION="${3:-}"
AWS_REGION="${4:-us-east-1}"

if [[ -z "$FUNCTION_NAME" || -z "$TARGET_VERSION" ]]; then
  echo "usage: $0 <function_name> <alias_name> <target_version> [aws_region]"
  exit 2
fi

aws lambda update-alias \
  --region "$AWS_REGION" \
  --function-name "$FUNCTION_NAME" \
  --name "$ALIAS_NAME" \
  --function-version "$TARGET_VERSION" \
  --routing-config "AdditionalVersionWeights={}"

echo "rollback complete: ${FUNCTION_NAME}:${ALIAS_NAME} -> v${TARGET_VERSION}"
