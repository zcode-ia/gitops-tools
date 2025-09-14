#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

# Set the Github repository directory
GIT_ROOT_DIR=$(git rev-parse --show-toplevel)

# Set the destination directory for extracted binary files
dest_dir="${GIT_ROOT_DIR}/bin"

# Only extracts binary files (excluding common text files)
# and only if they have not already been extracted (i.e., they don't exist in the destination directory).
# It works for both ZIP and TAR.GZ files.
extract_if_needed() {
    local file="$1"
    local binary_files

    # Determine the command to list files based on file type
    if [[ "$file" == *.zip ]]; then
        binary_files=$(unzip -Z1 "$file" | grep -vE -e '\.(txt|md|html|csv|json|xml|yaml|log|tpl)$' -e 'LICENSE')
    elif [[ "$file" == *.tar.gz ]]; then
        binary_files=$(tar -tzf "$file" | grep -vE -e '\.(txt|md|html|csv|json|xml|yaml|log|tpl)$' -e 'LICENSE')
    else
        return
    fi

    # If no binary files are found, skip extraction
    [[ -z "$binary_files" ]] && echo "No binary files found in $file, skipping." && return

    # Check if any of the binary files already exist
    for f in $binary_files; do
        [[ -e "$dest_dir/$f" ]] && echo " - Skipping $f, already extracted." && return
    done

    # Extract the binary files
    echo " - Extracting $binary_files from $file..."
    if [[ "$file" == *.zip ]]; then
        unzip "$file" "$binary_files" -d "$dest_dir"
    else
        tar -xzf "$file" -C "$dest_dir" "$binary_files"
    fi

    # Ensure each extracted binary file has execution mode enabled
    for f in $binary_files; do
        extracted_file="$dest_dir/$f"
        if [[ -f "$extracted_file" && ! -x "$extracted_file" ]]; then
            echo "   - Setting executable permission for $extracted_file"
            chmod +x "$extracted_file"
        fi
    done
}

# Check for binary files in the destination directory and extract them if necessary
check-binary-files() {
    echo "Checking for binary files to extract if necessary."
    for file in "$dest_dir"/*"${OSTYPE}"*.zip "$dest_dir"/*"${OSTYPE}"*.tar.gz; do
        echo "+ Analysing: $file"
        [[ -f "$file" ]] && extract_if_needed "$file"
    done
}

check-binary-files

exit 0
