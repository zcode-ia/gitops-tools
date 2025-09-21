#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

COMPARISON_BRANCHES=$1
shift
INPUT_GITHUB_BASE_BRANCH=$1
shift
INPUT_GITHUB_HEAD_BRANCH=$1
shift

IFS=',' read -ra BRANCHES <<< "$COMPARISON_BRANCHES"

cd "$GITHUB_WORKSPACE"
git fetch origin "$INPUT_GITHUB_BASE_BRANCH"
git fetch origin "$INPUT_GITHUB_HEAD_BRANCH"

COMMENT_TITLE="## Commit Ancestry Check\n\n"
COMMENT_OUTPUTS=""
ALL_BRANCHES_MISSING=true

for BRANCH in "${BRANCHES[@]}"; do
    echo "Checking branch: $BRANCH"
    git fetch origin "$BRANCH"

    UNMERGED_COMMITS=$(git cherry origin/"$BRANCH" origin/"$INPUT_GITHUB_HEAD_BRANCH" | grep '^+' | cut -c3- || true)

    if [ -n "$UNMERGED_COMMITS" ]; then
        echo "PR contains commits not found in $BRANCH"
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}- Branch ${BRANCH} [\`Commits Missing\`]\n"

        for COMMIT in $UNMERGED_COMMITS; do
            COMMIT_MSG=$(git log --format="%h %s" -n 1 "$COMMIT")
            COMMENT_OUTPUTS="${COMMENT_OUTPUTS}  - ${COMMIT_MSG}\n"
        done

        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}\n"
    else
        echo "All PR commits are present in $BRANCH"
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}- Branch ${BRANCH} [\`All Commits Present\`]\n\n"
        ALL_BRANCHES_MISSING=false
    fi
done

ENCODED_COMMENT_TITLE=$(echo -e "${COMMENT_TITLE}" | jq -Rsa . | base64 -w 0)
ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

# Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
echo "#${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}"

if [ "$ALL_BRANCHES_MISSING" = true ]; then
    exit 1
fi

exit 0
