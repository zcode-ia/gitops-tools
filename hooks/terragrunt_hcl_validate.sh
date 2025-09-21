#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

echo "🔍 Finding changed Terragrunt files..."

# Loop through all passed directories
for file in "$@"; do
    # Only consider .hcl files
    if [[ "$file" == "terragrunt.hcl" ]]; then
        dir=$(dirname "$file")

        echo "Validating $dir..."

        # Capture the exit code of hclvalidate
        if ! terragrunt hclvalidate --working-dir "$dir"; then
            echo "Terragrunt validate failed!"
            exit 1
        fi
    fi
done
