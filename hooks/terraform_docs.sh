#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

# Define the path to the Terraform doc configuration file
CONFIG_FILE="$(dirname "$0")/.terraform-docs.yml"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Terraform doc configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "🔍 Finding changed Terraform files..."

# Collect unique directories containing .tf files
declare -A dirs=()
for file in "$@"; do
    if [[ "$file" == *.tf ]]; then
        dir=$(dirname "$file")
        dirs["$dir"]=1
    fi
done

# Run terraform-docs once per unique directory
for dir in "${!dirs[@]}"; do
    echo "Generating documentation for $dir..."

    if ! terraform-docs --config "$CONFIG_FILE" "$dir"; then
        echo "Terraform docs generation failed for $dir"
        exit 1
    fi
done
