#!/bin/bash

# Bash safety flags:
# -e: exit on any error
# -u: treat unset variables as an error and exit
# -o pipefail: fail if any command in a pipeline fails
set -euo pipefail

ENCODED_WORKING_DIRS=$1
shift
INPUT_GITHUB_REPOSITORY=$1
shift
INPUT_GITHUB_RUN_ID=$1
shift
INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER=$1
shift
INPUT_GITHUB_TOKEN=$1
shift

# Ensure that the GITHUB_TOKEN is set for git operations
AUTH_URL="https://x-access-token:${INPUT_GITHUB_TOKEN}@github.com/"
git config --global url."${AUTH_URL}".insteadOf https://github.com/

# URL for the GitHub run ID
RUN_ID_URL="https://github.com/${INPUT_GITHUB_REPOSITORY}/actions/runs/${INPUT_GITHUB_RUN_ID}"

# File to store the output
TERRAGRUNT_RUNALL_OUTPUT_FILENAME=terragrunt_runall_output.txt
ARTIFACT_PATH_FILENAME="${GITHUB_WORKSPACE}/${INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER}-${INPUT_GITHUB_RUN_ID}-output.txt"

# Initialize variables to store title and all apply outputs
COMMENT_TITLE="## Apply result\n\n"
COMMENT_OUTPUTS="Show apply for the following directories:\n\n"
COMMENT_OUTPUTS_MAX_LENGTH=65000

# Decode the base64 encoded working directories
for WORKING_DIR in $(echo "${ENCODED_WORKING_DIRS}" | base64 -d); do
    # Check if the working directory exists
    if [ -d "${WORKING_DIR}" ]; then
        # Adding the directory name to the output
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}<details><summary>${WORKING_DIR}</summary>\n"

        echo "Applying ${WORKING_DIR}..." >> "${ARTIFACT_PATH_FILENAME}"

        # Run Terragrunt init in the directory
        terragrunt run-all init --non-interactive --no-color --working-dir "${WORKING_DIR}" --provider-cache

        # Run Terragrunt apply in the directory
        terragrunt run-all apply --non-interactive --no-color --working-dir "${WORKING_DIR}" --provider-cache 2>&1 | tee "${TERRAGRUNT_RUNALL_OUTPUT_FILENAME}"

        echo >> "${ARTIFACT_PATH_FILENAME}"
        # Extract the apply header from the output
        sed -E 's/^.*(The stack at .*)/\1/' "${TERRAGRUNT_RUNALL_OUTPUT_FILENAME}" | sed -E 's/^.*\[(.*)\].*terraform:\s?/\[\1\] : /' >> "${ARTIFACT_PATH_FILENAME}"

        APPLY_OUTPUT=$(cat "${ARTIFACT_PATH_FILENAME}")
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}\n\n<pre>${APPLY_OUTPUT}</pre>\n</details>"
        echo
    else
        echo "Directory ${WORKING_DIR} does not exist."
    fi
done

# Convert to base64 to avoid issues with special characters and newlines
ENCODED_COMMENT_TITLE=$(echo -e "$COMMENT_TITLE" | jq -Rsa . | base64 -w 0)
COMMENT_STATUS="pass"

if [ ! -f ${TERRAGRUNT_RUNALL_OUTPUT_FILENAME} ]; then
    # Set variables to warning no apply was performed
    COMMENT_OUTPUTS="No apply was performed. Check pipeline logs for more details. [${INPUT_GITHUB_RUN_ID}](${RUN_ID_URL})\n\n"
    ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

    # Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
    echo "#${COMMENT_STATUS}|${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}"
    exit 0
fi

if [[ ${#COMMENT_OUTPUTS} -gt ${COMMENT_OUTPUTS_MAX_LENGTH} ]]; then
    COMMENT_STATUS="fallback"

    echo "Comment output exceeds ${COMMENT_OUTPUTS_MAX_LENGTH} characters, the artifact file will be uploaded..."
    # Grouping the prefix and ordering the output file
        awk '
        /^\[[^]]+\]/ {
        prefix = substr($0, 1, index($0, "]"))
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", prefix)
        if (!(prefix in seen)) {
            seen[prefix] = 1
            order[++count] = prefix
        }
        data[prefix] = data[prefix] $0 "\n"
        }
        END {
        for (i = 1; i <= count; i++) {
            pf = order[i]
            print "### " pf
            printf "%s", data[pf]
            print ""
        }
        }
    ' "${ARTIFACT_PATH_FILENAME}" > "${ARTIFACT_PATH_FILENAME}.ordered"

    cp -f "${ARTIFACT_PATH_FILENAME}.ordered" "${ARTIFACT_PATH_FILENAME}"

    COMMENT_OUTPUTS="Content too long for github comments."
    ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

    # Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
    echo "#${COMMENT_STATUS}|${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}|${ARTIFACT_PATH_FILENAME}"
    exit 0
fi

# Escape the content of COMMENT_OUTPUTS for JSON and convert to base64 to avoid issues with special characters and newlines
ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

# Search for Error message in the output file
if grep -q "STDERR" "${TERRAGRUNT_RUNALL_OUTPUT_FILENAME}"; then
    COMMENT_STATUS="fallback"
    COMMENT_OUTPUTS="The pipeline has failed! Check the logs for more details. [${INPUT_GITHUB_RUN_ID}](${RUN_ID_URL})\n\n"
    ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

    # Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
    echo "#${COMMENT_STATUS}|${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}"

    echo "Error found in the output, failing the job..."
    exit 1
fi

# Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
echo "#${COMMENT_STATUS}|${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}"

exit 0
