#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

enable-pre-commit() {
    # Check if pre-commit is installed
    if command -v pre-commit &> /dev/null; then
        # Install pre-commit hooks
        pre-commit install
    else
        # Print error message if pre-commit is not found
        echo "Error: pre-commit not found! Please, install it."
        exit 1
    fi
}

enable-pre-commit

exit 0
