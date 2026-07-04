#!/usr/bin/env bash
set -euo pipefail

API_URL="${1:-}"
EXPECTED_CODES="${2:-200,202}"
PAYLOAD='{"test": true}'

if [[ -z "$API_URL" ]]; then
  echo "usage: $0 <api_url> [expected_codes_csv]"
  exit 2
fi

STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 \
  -X POST "${API_URL%/}/ingest" \
  -H "Content-Type: application/json" \
  -H "X-Smoke-Test: true" \
  -d "$PAYLOAD")

IFS=',' read -r -a CODES <<< "$EXPECTED_CODES"
for code in "${CODES[@]}"; do
  if [[ "$STATUS" == "$code" ]]; then
    echo "smoke-test ok: HTTP $STATUS"
    exit 0
  fi
done

echo "smoke-test failed: HTTP $STATUS (expected: $EXPECTED_CODES)"
exit 1
