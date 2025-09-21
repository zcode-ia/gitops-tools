#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

INPUT_GITHUB_TOKEN=$1
shift
INPUT_GITHUB_REPOSITORY=$1
shift
INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER=$1
shift
ENCODED_COMMENT_TITLE=$1
shift
ENCODED_COMMENT_OUTPUTS=$1
shift
ENCODED_COMMENT_RESULTS=$1
shift
ARTIFACT_COMMENT=$1
shift

COMMENT_TITLE=$(echo "${ENCODED_COMMENT_TITLE}" | base64 -d | jq -r .)
COMMENT_OUTPUTS=$(echo "${ENCODED_COMMENT_OUTPUTS}" | base64 -d | jq -r .)
COMMENT_RESULTS=$(echo "${ENCODED_COMMENT_RESULTS}" | base64 -d | jq -r .)

if [ -n "$ARTIFACT_COMMENT" ]; then
    COMMENT_OUTPUTS="${COMMENT_OUTPUTS}\n\n${ARTIFACT_COMMENT}"
fi

BODY_MESSAGE=$(echo -e "${COMMENT_RESULTS}\n\n${COMMENT_TITLE}\n\n${COMMENT_OUTPUTS}")

echo "BODY_MESSAGE=${BODY_MESSAGE}"

# Prepare the JSON payload safely
BODY_PAYLOAD=$(jq -nc --arg body "$BODY_MESSAGE" '{body: $body}')

# Create a temporary file to store the HTTP response
HTTP_RESPONSE=$(mktemp)

# Post the output as a single comment to the Pull Request
STATUS_RESPONSE=$(curl -s -o "$HTTP_RESPONSE" -X POST -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
-H "Accept: application/vnd.github.v3+json" \
https://api.github.com/repos/"${INPUT_GITHUB_REPOSITORY}"/issues/"${INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER}"/comments \
-d "${BODY_PAYLOAD}" -w "%{http_code}")

if [[ "$STATUS_RESPONSE" =~ ^2 ]]; then
    echo "Request succeeded with status: $STATUS_RESPONSE"
else
    echo "Request failed with status: $STATUS_RESPONSE"
    cat "$HTTP_RESPONSE"
    exit 1
fi

# Clean up the temporary file
rm -f "$HTTP_RESPONSE"

exit 0
