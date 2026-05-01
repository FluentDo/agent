#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"
ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_FILE_ROOT FLUENT_BIT_BINARY

load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

# bats file_tags=functional
teardown() {
    if [[ -n "${SKIP_TEARDOWN:-}" ]]; then
        echo "Skipping teardown"
    else
        # Clean up the git repository after each test to ensure a clean state for the next test
        stopFluentBit
    fi
}

# We are not testing libgit here but just the implementation of our plugin.
#
# We use a local git repository for testing as getting the SHA of PR commits
# is apparently a nightmare with Github plus it introduces a lot of extra
# complexity.
#
# We want to set up a simple local repo we can always access and then confirm
# the various configuration options for the git_config plugin work as expected.

setupRepo() {
    local repoDir=${1:-"$BATS_TEST_TMPDIR/repo"}
    rm -rf "${repoDir:?}"/
    mkdir -p "$repoDir"
    pushd "$repoDir"
        git init
        git branch -m main
        
        git config user.name "Test User"
        git config user.email "ignore@telemetryforge.io"

        cp "$BATS_TEST_DIRNAME/resources/"*.yaml .
        git add .
        git commit -m "Initial commit"
        echo "Made initial commit with SHA '$(git rev-parse HEAD)'"
    popd
}

setup() {
    # Remove any old instances
    stopFluentBit

    # Set up a local git repository with a simple config file we can use for testing
    GIT_REPO_PATH="$BATS_TEST_TMPDIR/repo"
    export GIT_REPO_PATH
    setupRepo "$GIT_REPO_PATH"

    # We will track the `main` branch
    GIT_SHA="main"
    export GIT_SHA
    echo "Set up git repository at '$GIT_REPO_PATH'"
}

@test "verify git config plugin basic configuration" {
    assert_file_exists "$BATS_TEST_DIRNAME/resources/initial-fluent-bit.yaml"
    assert_file_exists "$BATS_TEST_DIRNAME/resources/fluent-bit.yaml"

    # Verify the configuration files are valid and the plugin can start without errors with the provided configuration
    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/initial-fluent-bit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    # This is the one we should switch to after the first poll interval
    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/fluent-bit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/initial-fluent-bit.yaml"
    assert_success
    # Check we are correctly polling the repository and not encountering errors
    refute_output --partial '[error]'
    refute_output --partial 'failed to get remote SHA'
    refute_output --partial 'failed to extract config file'
    assert_output --partial 'new commit detected'
    # The output should contain the message about switching to the updated configuration after the first poll interval
    assert_output --partial 'Switched to updated configuration'
}

# Verify we can add a new commit to the repository and the plugin picks up the change without errors
@test "verify git config plugin picks up new commits" {
    # Verify the initial configuration is valid
    assert_file_exists "$BATS_TEST_DIRNAME/resources/initial-fluent-bit-no-exit.yaml"

    cat "$BATS_TEST_DIRNAME/resources/initial-fluent-bit-no-exit.yaml"

    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/initial-fluent-bit-no-exit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    # We run Fluent Bit with a config that does not have an exit explicitly
    startFluentBit -c "$BATS_TEST_DIRNAME/resources/initial-fluent-bit-no-exit.yaml"

    # Taken from the fluent-bit-no-exit.yaml file
    local initialMessage="Dummy initial message"
    local updatedMessage="Completely different configuration"

    # We wait for the initial configuration to be applied and then we make a new commit
    waitForOutput "$initialMessage" 30
    markLogPosition

    # Make a new commit to the repository with the updated configuration
    pushd "$GIT_REPO_PATH"
        sed -i "s/$initialMessage/$updatedMessage/" fluent-bit-no-exit.yaml
        cat fluent-bit-no-exit.yaml
        git add .
        git commit -m "Update configuration"
        echo "Made new commit with SHA '$(git rev-parse HEAD)'"
    popd
    
    # We then check the output to confirm the new commit was detected and the configuration was switched to the updated one
    waitForNewOutput "$updatedMessage" 30
    markLogPosition

    stopFluentBit
}
