# BATS tests

To run tests use the [`run-bats.sh`](./run-bats.sh) script in this directory.
It is intended to verify the basic set up as well as ensuring we pass appropriate variables.

There are scripts to run local integration tests as well:

- `run-container-integration-tests.sh`
- `run-k8s-integration-tests.sh`
- `run-package-functional-tests.sh`
- `run-package-integration-tests.sh`

These are split into [functional tests](./tests/functional/) you can easily run directly with the binary and inside the container with no external dependencies required and [integration tests](./tests/integration/) that require more infrastructure or external dependencies to run with.

Functional tests are intended to be standalone and simple, e.g. no additional external dependencies to send to an output or read an input.
They will be run inside containers as well as directly on the target OS potentially.

Integration tests are intended for when we want to verify more complex behaviour, e.g. sending to a specific backend so we can run it up to check.

In each case the intent is to make as many common tests that can be reused across all targets as possible but there are also some target-specific tests (e.g. Windows-only inputs) that can be run just on the specific targets.

Samples have been provided to demonstrate usage.

Tests should support parallel runs so ensure they are idempotent by cleaning up all expected resources both before and after a test.

## Running tests locally

Most test scripts are wrappers around [`run-bats.sh`](./run-bats.sh), and `run-bats.sh` can also be used directly for ad-hoc runs.

### General BATS runner (`run-bats.sh`)

Run everything:

```bash
./run-bats.sh
```

Run specific suites/tags:

```bash
./run-bats.sh --filter-tags integration --recursive ./tests
./run-bats.sh --filter-tags '!k8s,!container' --recursive ./tests
```

Useful environment variables:

- `FLUENT_BIT_BINARY` (default: `/fluent-bit/bin/fluent-bit`)
- `TELEMETRY_FORGE_AGENT_VERSION` (default: `26.7.2`)
- `TELEMETRY_FORGE_AGENT_URL` (default: `https://staging.telemetryforge.io`)

Target selection rule:

- When changing distro target, set **both** `DISTRO` and `BASE_IMAGE` together so package build/download and test container base stay aligned.
- `BASE_IMAGE` must be a compatible `dokken/` image for the selected `DISTRO`.
- Use this mapping rule: `BASE_IMAGE=dokken/${DISTRO//\//-}` (replace `/` with `-`).
- `CONTAINER_RUNTIME` (default: `docker`)
- `BATS_FORMATTER` (default: `tap`)
- `BATS_ARGS` (default: `--timing --verbose-run --print-output-on-failure`)
- `BATS_TEST_TIMEOUT` (default: `300` seconds)
- `BATS_DEBUG` (set to non-zero for shell tracing)
- `BATS_NUMBER_OF_PARALLEL_JOBS` and `BATS_PARALLEL_BINARY_NAME` (parallel execution tuning)
- `DETIK_CLIENT_NAME` (default: `kubectl`)
- `HELPERS_ROOT` (override helper function location)

Notes:

- Any CLI arguments passed to `run-bats.sh` are forwarded directly to `bats`.
- If no arguments are provided, it runs recursively under `./tests`.

### Container integration tests (`run-container-integration-tests.sh`)

This script runs integration tests tagged for container scenarios.

Required environment variables:

- `TELEMETRY_FORGE_AGENT_IMAGE`
- `TELEMETRY_FORGE_AGENT_TAG`

Optional environment variables:

- `CONTAINER_RUNTIME` (default: `docker`)

Example:

```bash
TELEMETRY_FORGE_AGENT_IMAGE=ghcr.io/telemetryforge/agent/ubi \
TELEMETRY_FORGE_AGENT_TAG=main \
./run-container-integration-tests.sh
```

### Package functional tests (`run-package-functional-tests.sh`)

This script builds a test container and runs package functional tests.

Useful environment variables:

- `CONTAINER_RUNTIME` (default: `docker`)
- `BASE_IMAGE` (default: `dokken/centos-6`)
- `DISTRO` (default: `centos/6`)
- `FLUENT_BIT_BINARY` (default: `/opt/telemetryforge-agent/bin/fluent-bit`)
- `DOWNLOAD_DIR` (default: `$PWD/downloads`)
- `CLEAN_DOWNLOAD` (set non-empty to wipe `DOWNLOAD_DIR` before test)
- `BUILD_PACKAGE` (set non-empty to build a package locally before testing)
- `TELEMETRY_FORGE_AGENT_VERSION` (default: `26.7.2`)
- `TELEMETRY_FORGE_AGENT_URL` (default: `https://staging.telemetryforge.io`)

Behavior:

- If package files (`.rpm`/`.deb`) already exist in `DOWNLOAD_DIR`, those are used.
- If no package files exist:
    - in CI (`CI` is set), the script fails.
    - locally, it either builds (`BUILD_PACKAGE` set) or downloads packages (`install.sh --download`).

Examples:

```bash
# Use pre-downloaded packages in ./downloads
./run-package-functional-tests.sh

# Build package locally first, then test for Ubuntu 24
DISTRO=ubuntu/24 BASE_IMAGE=dokken/ubuntu-24 BUILD_PACKAGE=1 ./run-package-functional-tests.sh

# Build package locally first, then test for Debian bookworm
DISTRO=debian/bookworm BASE_IMAGE=dokken/debian-bookworm BUILD_PACKAGE=1 ./run-package-functional-tests.sh

# Force package refresh and use podman
CONTAINER_RUNTIME=podman CLEAN_DOWNLOAD=1 DISTRO=almalinux/8 BASE_IMAGE=dokken/almalinux-8 ./run-package-functional-tests.sh
```

### Package integration tests (`run-package-integration-tests.sh`)

This script runs integration tests excluding container and k8s tags.

Useful environment variables:

- `FLUENT_BIT_BINARY` (default: `/opt/telemetryforge-agent/bin/fluent-bit`)

Example:

```bash
FLUENT_BIT_BINARY=/opt/telemetryforge-agent/bin/fluent-bit ./run-package-integration-tests.sh
```

### Kubernetes integration tests (`run-k8s-integration-tests.sh`)

This script creates a KIND cluster, prepares an image, and runs k8s integration tests.

Useful environment variables:

- `CONTAINER_RUNTIME` (default: `docker`)
- `TELEMETRY_FORGE_AGENT_IMAGE` (default: `ghcr.io/telemetryforge/agent/ubi`)
- `TELEMETRY_FORGE_AGENT_TAG` (default: `main`; set to `local` to build locally)
- `KIND_CLUSTER_NAME` (default: `kind`)
- `KIND_VERSION` (default: `v1.34.0`)
- `KIND_NODE_IMAGE` (default: `kindest/node:${KIND_VERSION}`)

CLI arguments:

- Optional: pass any `bats` arguments to run specific tests.
- If no args are provided, it runs `--filter-tags 'integration,k8s' --recursive ./tests`.

Example:

```bash
# Run default k8s integration suite
./run-k8s-integration-tests.sh

# Run a single file through bats args
./run-k8s-integration-tests.sh ./tests/integration/k8s/example.bats
```

## Tags

We provide common tags for every test case to make it simpler to select (or exclude) tests: <https://bats-core.readthedocs.io/en/stable/writing-tests.html#tagging-tests>.

The currently supported tags are:

- `k8s`
- `container`
- `linux`
- `macos`
- `windows`
- `functional`
- `integration`

Please ensure to correctly tag either the whole file or specific tests as required, e.g.

```bash
# bats file_tags=integration,k8s
```

We can then select multiple or single tags as well as exclude by tag too using `--filter-tags`.

## Helper functions and libraries

Common and useful functions can be found in the `helpers/test-helpers.bash` file which can be loaded as required at the start of every `.bats` test file.

Additionally we provide some useful helper libraries under the `lib` directory which can be loaded like so:

```bash
#!/usr/bin/env bash
load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_FILE_ROOT

load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"
```

To update the helper libraries there is an [`update-bats-versions.sh`](./../../scripts/update-bats-versions.sh) script provided.

Ensure to honour the `SKIP_TEARDOWN` parameter being set as well so local runs can be easily debugged by skipping teardown.

```bash
function teardown() {
    if [[ -n "${SKIP_TEARDOWN:-}" ]]; then
        echo "Skipping teardown"
    else
        helm uninstall --namespace "$NAMESPACE" "$HELM_RELEASE_NAME" || true
        kubectl delete namespace "$NAMESPACE" || true
    fi
}
```
