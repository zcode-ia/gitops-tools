#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

init-git-submodule() {
    # Check if git is installed
    if command -v git &> /dev/null; then
        # Init git submodule
        git submodule update --init --recursive --remote --merge
    else
        # Print error message if git is not found
        echo "Error: git not found! Please, install it."
        exit 1
    fi
}

init-git-submodule

exit 0
