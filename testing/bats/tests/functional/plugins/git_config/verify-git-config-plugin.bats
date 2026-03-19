#!/usr/bin/env bats

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_FILE_ROOT FLUENT_BIT_BINARY

load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

# bats file_tags=functional
setup() {
}

teardown() {
    if [[ -n "${SKIP_TEARDOWN:-}" ]]; then
        echo "Skipping teardown"
    fi
}

@test "verify git config plugin basic configuration" {
    # Verify the configuration files are valid and the plugin can start without errors with the provided configuration
    run "$FLUENT_BIT_BINARY" -c "$BATS_FILE_ROOT/resources/initial-fluent-bit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    # This is the one we should switch to after the first poll interval
    run "$FLUENT_BIT_BINARY" -c "$BATS_FILE_ROOT/resources/fluent-bit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    run "$FLUENT_BIT_BINARY" -c "$BATS_FILE_ROOT/resources/initial-fluent-bit.yaml"
    assert_success
    # Check we are correctly polling the repository and not encountering errors extracting the config file
    assert_output --partial 'polling repository https://github.com/telemetryforge/agent.git'
    refute_output --partial 'failed to extract config file'
    # The output should contain the message about switching to the updated configuration after the first poll interval
    assert_output --partial 'Switched to updated configuration'
}
