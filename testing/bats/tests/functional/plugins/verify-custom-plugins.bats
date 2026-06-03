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
    fi
}

@test "verify git_config plugin exists" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "git_config"
    run "$FLUENT_BIT_BINARY" -C git_config --help
    assert_success
    refute_output --partial "[error]"
}

@test "verify custom telemetryforge plugin exists" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "telemetryforge"
    run "$FLUENT_BIT_BINARY" -C "telemetryforge" --help
    assert_success
    refute_output --partial "[error]"
}

# Processors cannot be individually queried unfortunately like custom plugins so we just check for their existence in the help output
@test "verify log_sampling processor exists" {
    PLUGIN_NAME="log_sampling"
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "$PLUGIN_NAME"
}

@test "verify de-duplication processor exists" {
    PLUGIN_NAME="dedup"
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "$PLUGIN_NAME"
}

