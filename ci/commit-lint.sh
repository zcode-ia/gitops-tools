#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

BASE_SHA=$1
shift
HEAD_SHA=$1
shift

COMMITS=$(git log "$BASE_SHA".."$HEAD_SHA" --pretty=format:"%H")
echo "Linting commits:"
echo "$COMMITS"

echo "$COMMITS" | while read -r COMMIT; do
echo "Checking commit: $COMMIT"
npx commitlint --from "$COMMIT"^ --to "$COMMIT"
done

exit 0
