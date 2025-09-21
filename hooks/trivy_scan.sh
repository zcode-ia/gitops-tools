#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

# Define the path to the Trivy configuration file
CONFIG_FILE="$(dirname "$0")/trivy.yaml"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Trivy configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "🔍 Finding changed Terraform files..."

# Loop through all passed files or directories
for file in "$@"; do
    # Only consider .tf files
    if [[ "$file" == *.tf ]]; then
        echo "Scanning $file with Trivy using config $CONFIG_FILE..."

        # Capture the exit code of Trivy
        if ! trivy config -c "$CONFIG_FILE" "$file"; then
            echo "Trivy scan failed for $file"
            exit 1
        fi
    fi
done
