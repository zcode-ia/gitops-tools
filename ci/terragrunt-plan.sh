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
INFRACOST_API_KEY=$1
shift

export INFRACOST_API_KEY=$INFRACOST_API_KEY

# Ensure that the GITHUB_TOKEN is set for git operations
AUTH_URL="https://x-access-token:${INPUT_GITHUB_TOKEN}@github.com/"
git config --global url."${AUTH_URL}".insteadOf https://github.com/

# URL for the GitHub run ID
RUN_ID_URL="https://github.com/${INPUT_GITHUB_REPOSITORY}/actions/runs/${INPUT_GITHUB_RUN_ID}"

# File to store the output
TERRAGRUNT_RUNALL_OUTPUT_FILENAME=terragrunt_runall_output.txt
ARTIFACT_PATH_FILENAME="${GITHUB_WORKSPACE}/${INPUT_GITHUB_EVENT_PULL_REQUEST_NUMBER}-${INPUT_GITHUB_RUN_ID}-output.txt"

# Initialize variables to store title and all plan outputs
COMMENT_TITLE="## Plan result\n\n"
COMMENT_OUTPUTS="Show plan for the following directories:\n\n"
COMMENT_OUTPUTS_MAX_LENGTH=65000

# Decode the base64 encoded working directories
for WORKING_DIR in $(echo "${ENCODED_WORKING_DIRS}" | base64 -d); do
    # Check if the working directory exists
    if [ -d "${WORKING_DIR}" ]; then
        # Adding the directory name to the output
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}<details><summary>${WORKING_DIR}</summary>\n"

        echo "Planning ${WORKING_DIR}..." >> "${ARTIFACT_PATH_FILENAME}"

        # Run Terragrunt init in the directory
        terragrunt run-all init --non-interactive --no-color --working-dir "${WORKING_DIR}" --provider-cache

        # Run Terragrunt plan in the directory
        terragrunt run-all plan --out=plan.tfplan --non-interactive --no-color --working-dir "${WORKING_DIR}" --provider-cache 2>&1 | tee "${TERRAGRUNT_RUNALL_OUTPUT_FILENAME}"

        # Extract the plan header from the output
        PLAN_HEADER=$(awk '/The stack at/ {flag=1; print substr($0, index($0, "The stack at")); next} /Terraform used the selected providers to generate/ {flag=0} flag' "${TERRAGRUNT_RUNALL_OUTPUT_FILENAME}")

        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}\n\n<pre>${PLAN_HEADER}</pre>\n"
        echo >> "${ARTIFACT_PATH_FILENAME}"
        echo -e "${PLAN_HEADER}\n\n" >> "${ARTIFACT_PATH_FILENAME}"

        # List all plan files, ordering by creation time
        for PLAN_DIR in $(find "${WORKING_DIR}" -name plan.tfplan -printf '%T@ %h\n' | sort -n | cut -d' ' -f2-); do
            RESOURCE_DIR=$(echo "${PLAN_DIR}" | sed -E "s|^${WORKING_DIR}/||; s|/\.terragrunt-cache.*||")

            echo "Saving ${RESOURCE_DIR} plan content..."

            # Capture the Terraform plan output
            PLAN_OUTPUT=$(terraform -chdir="${PLAN_DIR}" show -no-color plan.tfplan)

            echo "Saving ${RESOURCE_DIR} infracost content..."
            # Capture the Infracost breakdown output
            INFRACOST_OUTPUT=$(infracost breakdown --path "${PLAN_DIR}")

            # Append the output to the aggregated variable
            COMMENT_OUTPUTS="${COMMENT_OUTPUTS}\n\n#### Plan for ${RESOURCE_DIR}\n\n<pre>${PLAN_OUTPUT}<br><br>${INFRACOST_OUTPUT}</pre>\n"
            echo -e "\nPlan for ${RESOURCE_DIR}\n${PLAN_OUTPUT}\n\n" >> "${ARTIFACT_PATH_FILENAME}"
            echo -e "${INFRACOST_OUTPUT}\n\n" >> "${ARTIFACT_PATH_FILENAME}"
        done
        COMMENT_OUTPUTS="${COMMENT_OUTPUTS}</details>"
        echo
    else
        echo "Directory ${WORKING_DIR} does not exist."
    fi
done

# Convert to base64 to avoid issues with special characters and newlines
ENCODED_COMMENT_TITLE=$(echo -e "$COMMENT_TITLE" | jq -Rsa . | base64 -w 0)
COMMENT_STATUS="pass"

if [ ! -f ${TERRAGRUNT_RUNALL_OUTPUT_FILENAME} ]; then
    # Set variables to warning no plan was generated
    COMMENT_OUTPUTS="No plan was generated. Check pipeline logs for more details. [${INPUT_GITHUB_RUN_ID}](${RUN_ID_URL})\n\n"
    ENCODED_COMMENT_OUTPUTS=$(echo -e "$COMMENT_OUTPUTS" | jq -Rsa . | base64 -w 0)

    # Output the results in a format that can be captured by the calling script. The character "#" at the begging mark the echo output to be used. The character "|" is used as a delimiter.
    echo "#${COMMENT_STATUS}|${ENCODED_COMMENT_TITLE}|${ENCODED_COMMENT_OUTPUTS}"
    exit 0
fi

if [[ ${#COMMENT_OUTPUTS} -gt ${COMMENT_OUTPUTS_MAX_LENGTH} ]]; then
    COMMENT_STATUS="fallback"

    echo "Comment output exceeds ${COMMENT_OUTPUTS_MAX_LENGTH} characters, uploading artifact..."
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
