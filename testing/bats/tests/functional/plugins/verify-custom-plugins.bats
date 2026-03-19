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

@test "verify git_config plugin exists" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "git_config"
    run "$FLUENT_BIT_BINARY" -C git_config --help
    assert_success
    refute_output --partial "[error]"
    refute_output --partial "tried to instance a plugin name that doesn't exist"
}

@test "verify log_sampling processor exists" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "log_sampling"
}

@test "verify dedupe processor exists" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success
    assert_output --partial "dedupe"
}

