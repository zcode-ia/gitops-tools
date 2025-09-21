#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

FILTER=$1
shift
ENCODED_MODIFIED_FILES_TO_FILTER=$1
shift

# File to store the filtered directories of modified files
FILTERED_WORKING_DIRS_FILENAME=filtered_working_dirs.txt

# Decode the base64 encoded MODIFIED_FILES and extract the parent folder
FILTERED_WORKING_DIRS=$(echo "${ENCODED_MODIFIED_FILES_TO_FILTER}" | base64 -d | grep "${FILTER}" || true)

if [ -z "${FILTERED_WORKING_DIRS}" ]; then
    echo "No modified files found in the working directory."
    FILTERED_WORKING_DIRS_COUNT=0
    echo "#${FILTERED_WORKING_DIRS_COUNT}"
    exit 0
fi

echo "${FILTERED_WORKING_DIRS}" | sed -E 's|/[^/]+/[^/]+$||' | sort -u > ${FILTERED_WORKING_DIRS_FILENAME}

# Check if the parent directory is empty after sed processing
if [ ! -s ${FILTERED_WORKING_DIRS_FILENAME} ]; then
    echo "No parent directories found after processing."
    FILTERED_WORKING_DIRS_COUNT=0
    echo "#${FILTERED_WORKING_DIRS_COUNT}"
    exit 0
fi

# Remove any directory that is a subdirectory of another in the list (keep only shallowest parents)
mapfile -t dirs < "${FILTERED_WORKING_DIRS_FILENAME}"

# Only keep paths that are NOT exactly 'live'
filtered_dirs=()
for dir in "${dirs[@]}"; do
    [[ "$dir" == "live" || "$dir" == "${FILTER}" ]] && continue
    filtered_dirs+=("$dir")
done

unique_dirs=()
for dir in "${filtered_dirs[@]}"; do
    skip=
    for other in "${filtered_dirs[@]}"; do
        if [[ "$dir" != "$other" && "$dir" == "$other/"* ]]; then
            skip=1
            break
        fi
    done
    [[ -z "$skip" ]] && unique_dirs+=("$dir")
done

if [ "${#unique_dirs[@]}" -eq 0 ]; then
    echo "No working directories found after filtering."
    FILTERED_WORKING_DIRS_COUNT=0
    echo "#${FILTERED_WORKING_DIRS_COUNT}"
    exit 0
fi

echo "Final filtered working directories:"
for dir in "${unique_dirs[@]}"; do
    echo "$dir"
done

# Count the working directories to be processed
FILTERED_WORKING_DIRS_COUNT=${#unique_dirs[@]}
echo "Found ${FILTERED_WORKING_DIRS_COUNT} directory(ies) to be processed in ${FILTER}."

# Set the working directories and convert to base64 to avoid issues with special characters and newlines
ENCODED_FILTERED_WORKING_DIRS=$(printf "%s\n" "${unique_dirs[@]}" | base64 -w 0)

# Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
echo "#${FILTERED_WORKING_DIRS_COUNT}|${ENCODED_FILTERED_WORKING_DIRS}"

exit 0
