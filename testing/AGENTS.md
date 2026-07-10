# AGENTS

This file is the local operating guide for agents working in this repository.
It focuses on test authoring and execution for `testing/bats`.

## Scope and intent

Use this guide when you are:

- adding or updating BATS tests
- changing test helper scripts in `testing/bats`
- validating package or container behavior across targets

## Where tests live

- Functional tests: `testing/bats/tests/functional`
- Integration tests: `testing/bats/tests/integration`
- Shared helpers: `testing/bats/helpers`
- BATS runner and wrappers: `testing/bats/run-*.sh`

## Documentation rules

When changing test scripts, test layout, tags, helper behavior, or run instructions:

1. Update `testing/bats/README.md` in the same PR.
2. Keep examples executable as-is.
3. Document only user-facing flags/env vars.
4. Do not document internal path-resolution variables (for example script directory internals).

## Test authoring rules

- Tag tests accurately (`functional`, `integration`, `k8s`, `container`, OS tags as needed).
- Keep tests idempotent: create and clean up all resources they use.
- Honor `SKIP_TEARDOWN` in destructive teardown code to support local debugging.
- Prefer helpers from `testing/bats/helpers/test-helpers.bash` over duplicated shell logic.
- Use explicit assertions and print useful context on failures.

## Prerequisites by workflow

General BATS runs (`run-bats.sh`):

- `bats`

Container integration (`run-container-integration-tests.sh`):

- `bats`
- container runtime (`docker` by default, `podman` if `CONTAINER_RUNTIME=podman`)

Kubernetes integration (`run-k8s-integration-tests.sh`):

- `bats`
- `kubectl`
- `helm`
- `kind`
- container runtime

Package functional (`run-package-functional-tests.sh`):

- container runtime
- package artifacts available in `DOWNLOAD_DIR`, or allow script to build/download

Package integration (`run-package-integration-tests.sh`):

- `bats`
- package install under test with usable Fluent Bit binary path

## Standard commands

Run all BATS tests:

```bash
cd testing/bats
./run-bats.sh
```

Run only integration tests (excluding container/k8s):

```bash
cd testing/bats
./run-bats.sh --filter-tags 'integration,!container,!k8s' --recursive ./tests
```

Run container integration tests (image required):

```bash
cd testing/bats
TELEMETRY_FORGE_AGENT_IMAGE=ghcr.io/telemetryforge/agent/ubi \
TELEMETRY_FORGE_AGENT_TAG=main \
./run-container-integration-tests.sh
```

Run k8s integration tests against remote image:

```bash
cd testing/bats
./run-k8s-integration-tests.sh
```

Run k8s integration tests with a locally built image:

```bash
cd testing/bats
TELEMETRY_FORGE_AGENT_TAG=local \
TELEMETRY_FORGE_AGENT_IMAGE=ghcr.io/telemetryforge/agent/ubi \
./run-k8s-integration-tests.sh
```

Run package functional tests using existing local packages:

```bash
cd testing/bats
./run-package-functional-tests.sh
```

Run package functional tests for a specific distro target and build package first:

```bash
cd testing/bats
DISTRO=ubuntu/24 BASE_IMAGE=dokken/ubuntu-24 BUILD_PACKAGE=1 CLEAN_DOWNLOAD=1 ./run-package-functional-tests.sh
DISTRO=debian/bookworm BASE_IMAGE=dokken/debian-bookworm BUILD_PACKAGE=1 CLEAN_DOWNLOAD=1 ./run-package-functional-tests.sh
DISTRO=almalinux/8 BASE_IMAGE=dokken/almalinux-8 BUILD_PACKAGE=1 CLEAN_DOWNLOAD=1 ./run-package-functional-tests.sh
```

Run package functional tests with a non-default container runtime:

```bash
cd testing/bats
CONTAINER_RUNTIME=podman CLEAN_DOWNLOAD=1 DISTRO=ubuntu/24 BASE_IMAGE=dokken/ubuntu-24 ./run-package-functional-tests.sh
```

Run package integration tests:

```bash
cd testing/bats
FLUENT_BIT_BINARY=/opt/telemetryforge-agent/bin/fluent-bit ./run-package-integration-tests.sh
```

## Build and test target notes

- Set both `DISTRO` and `BASE_IMAGE` together for package functional target selection.
- `BASE_IMAGE` must be a compatible `dokken/` image for the selected `DISTRO`.
- Use this mapping rule: `BASE_IMAGE=dokken/${DISTRO//\//-}` (replace `/` with `-`).
- `BUILD_PACKAGE=1` triggers local package build for the selected distro before running package functional tests.
- `TELEMETRY_FORGE_AGENT_TAG=local` in k8s flow triggers a local image build (UBI or Debian Dockerfile selected by image name).
- `TELEMETRY_FORGE_AGENT_IMAGE` and `TELEMETRY_FORGE_AGENT_TAG` are required for container integration flow.

## Useful environment variables

Common runner controls:

- `BATS_ARGS`
- `BATS_FORMATTER`
- `BATS_TEST_TIMEOUT`
- `BATS_DEBUG`
- `BATS_NUMBER_OF_PARALLEL_JOBS`
- `BATS_PARALLEL_BINARY_NAME`
- `CONTAINER_RUNTIME`

Test payload/version controls:

- `FLUENT_BIT_BINARY`
- `TELEMETRY_FORGE_AGENT_VERSION`
- `TELEMETRY_FORGE_AGENT_URL`

Package functional controls:

- `DISTRO`
- `BASE_IMAGE`
- `DOWNLOAD_DIR`
- `CLEAN_DOWNLOAD`
- `BUILD_PACKAGE`

Kubernetes controls:

- `KIND_CLUSTER_NAME`
- `KIND_VERSION`
- `KIND_NODE_IMAGE`

## Change validation checklist

Before finishing changes to test code or test scripts:

1. Run at least the directly affected test workflow locally.
2. For target-specific changes, run on at least one representative target.
3. If tags changed, validate `--filter-tags` behavior still selects expected tests.
4. Update `testing/bats/README.md` to match real script behavior and defaults.
5. Keep changes focused; do not alter unrelated workflows or packaging logic.
