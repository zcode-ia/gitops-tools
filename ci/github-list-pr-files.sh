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

API_RESPONSE_FILENAME=api_response.json
MODIFIED_FILES_FILENAME=modified_files.txt
PR_FILES_COUNT=0

true > "${MODIFIED_FILES_FILENAME}"

page=1
per_page=100

while :; do
    # Use the GitHub API with pagination to fetch the list of modified files
    STATUS_RESPONSE=$(curl -s -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/${INPUT_GITHUB_REPOSITORY}/pulls/${INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER}/files?per_page=$per_page&page=$page" \
        -o ${API_RESPONSE_FILENAME} -w "%{http_code}")

    if [[ "$STATUS_RESPONSE" =~ ^2 ]]; then
        echo "Request succeeded with status: $STATUS_RESPONSE"
    else
        echo "Request failed with status: $STATUS_RESPONSE"
        cat "$API_RESPONSE_FILENAME"
        exit 1
    fi

    FILES_FOUND=$(jq -r '.[].filename' "$API_RESPONSE_FILENAME")
    if [ -z "$FILES_FOUND" ]; then
        break
    fi

    # Show the modified files
    echo "$FILES_FOUND" | tee -a $MODIFIED_FILES_FILENAME

    # Check if less than per_page results returned (last page)
    COUNT=$(echo "$FILES_FOUND" | wc -l)
    if [ "$COUNT" -lt "$per_page" ]; then
        break
    fi
    page=$((page+1))
done

# Check the filenames from the API response
if [ ! -s "$MODIFIED_FILES_FILENAME" ]; then
    echo "- No filename found in the API response"
    # Output the results in a format that can be captured by the calling script
    echo "#${PR_FILES_COUNT}"
    exit 0
fi

# Set the modified files as an environment variable and convert to base64 to avoid issues with special characters and newlines
ENCODED_MODIFIED_FILES=$(cat ${MODIFIED_FILES_FILENAME} | base64 -w 0)

# Count the number of modified files
PR_FILES_COUNT=$(wc -l < ${MODIFIED_FILES_FILENAME})

# Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
echo "#${PR_FILES_COUNT}|${ENCODED_MODIFIED_FILES}"

exit 0
