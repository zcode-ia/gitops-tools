#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

enable-direnv() {
    # Check if direnv is installed
    if command -v direnv &> /dev/null; then
        # Allow direnv to load the environment variables from .envrc
        direnv allow .
    else
        # Print error message if direnv is not found
        echo "Error: direnv not found! Please, install it."
        exit 1
    fi
}

enable-direnv

exit 0
