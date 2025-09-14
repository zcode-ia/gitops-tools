#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

install-npm-dependencies() {
    # Check if npm is installed
    if command -v npm &> /dev/null; then
        # Install npm dependencies
        npm install
    else
        # Print error message if npm is not found
        echo "Error: npm not found! Please, install it."
        exit 1
    fi
}

install-npm-dependencies

exit 0
