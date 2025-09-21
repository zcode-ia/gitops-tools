#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

STEP_MAIN_OUTCOME=$1
shift

if [[ "${STEP_MAIN_OUTCOME}" == "success" ]]; then
    echo "The workflow completed successfully."
else
    echo "The workflow failed. Please check the logs for details."
    exit 1
fi

exit 0
