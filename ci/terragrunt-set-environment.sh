#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

INPUT_GITHUB_BASE_REF=$1
shift

# Set the working directory based on the base branch
if [[ "$INPUT_GITHUB_BASE_REF" == "main" ]]; then
    WORKING_DIR=live/prod
else
    WORKING_DIR=live/$INPUT_GITHUB_BASE_REF
fi

# Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used.
echo "#${WORKING_DIR}"

exit 0
