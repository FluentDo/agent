#!/bin/bash
set -euo pipefail

# Update (if required) the pinned reusable workflow SHA used by .github/workflows/release-build.yaml

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
    SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
    SOURCE=$(readlink "$SOURCE")
    [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

TARGET_WORKFLOW=${TARGET_WORKFLOW:-"${SCRIPT_DIR}/../.github/workflows/release-build.yaml"}

# shellcheck disable=SC1091
source "$SCRIPT_DIR"/common.sh

if ! command -v gh &>/dev/null; then
	echo "ERROR: Missing gh command"
	exit 1
fi

# Verify gh CLI is authenticated
if [[ -z "${GH_TOKEN:-}" ]]; then
    if ! gh auth status >/dev/null 2>&1; then
        echo "ERROR: GH_TOKEN is not set and gh is not authenticated"
        echo "Run 'gh auth login' or set GH_TOKEN"
        exit 1
    fi
fi

if [[ ! -f "$TARGET_WORKFLOW" ]]; then
    echo "ERROR: Target workflow not found: $TARGET_WORKFLOW"
    exit 1
fi

# Get the latest commit SHA from the main branch of the documentation repo
LATEST_SHA=$(gh api repos/telemetryforge/documentation/commits/main --jq .sha)

sed_wrapper -i -E "s#(uses:[[:space:]]*telemetryforge/documentation/\.github/workflows/call-add-mapping-version\.yaml@)[0-9a-f]{40}#\1${LATEST_SHA}#" "$TARGET_WORKFLOW"

if ! grep -q "call-add-mapping-version.yaml@${LATEST_SHA}" "$TARGET_WORKFLOW"; then
    echo "ERROR: Failed to update pinned SHA in $TARGET_WORKFLOW"
    exit 1
fi

echo "INFO: Updated pinned SHA in $TARGET_WORKFLOW to $LATEST_SHA"
