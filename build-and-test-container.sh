#!/bin/bash
set -euo pipefail

# Simple script to build and test the agent image in a KIND cluster

SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE=$SCRIPT_DIR/$SOURCE
done
SCRIPT_DIR=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

# Set this to /ubi to build UBI image, otherwise Debian image is built
export TELEMETRY_FORGE_AGENT_IMAGE=${TELEMETRY_FORGE_AGENT_IMAGE:-ghcr.io/telemetryforge/agent/ubi}
# Set this to `local` to build and use a local image
export TELEMETRY_FORGE_AGENT_TAG=${TELEMETRY_FORGE_AGENT_TAG:-local}

# Extract the last section of the image name to use as the suffix for the Dockerfile to use, i.e. Dockerfile.ubi or Dockerfile.debian
if [[ "$TELEMETRY_FORGE_AGENT_IMAGE" == *"ubi" ]]; then
    echo "INFO: Building UBI image"
    DOCKERFILE="Dockerfile.ubi"
else
    echo "INFO: Building Debian image"
    DOCKERFILE="Dockerfile.debian"
fi

${CONTAINER_RUNTIME:-docker} build --target=production \
  -t "${TELEMETRY_FORGE_AGENT_IMAGE}:${TELEMETRY_FORGE_AGENT_TAG}" \
  -f "$SCRIPT_DIR/$DOCKERFILE" "$SCRIPT_DIR/"

${CONTAINER_RUNTIME:-docker} build --target=test \
  -t "${TELEMETRY_FORGE_AGENT_IMAGE}:${TELEMETRY_FORGE_AGENT_TAG}-test" \
  -f "$SCRIPT_DIR/$DOCKERFILE" "$SCRIPT_DIR/"

docker run --rm -t -e TELEMETRY_FORGE_AGENT_IMAGE="${TELEMETRY_FORGE_AGENT_IMAGE}" -e TELEMETRY_FORGE_AGENT_TAG="${TELEMETRY_FORGE_AGENT_TAG}" "${TELEMETRY_FORGE_AGENT_IMAGE}:${TELEMETRY_FORGE_AGENT_TAG}-test"
"$SCRIPT_DIR"/testing/bats/run-container-integration-tests.sh
