#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_FILE_ROOT FLUENT_BIT_BINARY TELEMETRY_FORGE_AGENT_VERSION

load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

# bats file_tags=functional

@test "verify preset env vars are always set" {
    run "$FLUENT_BIT_BINARY" --help
    assert_success

    # Check that the env vars are set
    assert_output --partial 'Distro  ='
    assert_output --partial 'Package ='
    assert_output --partial "Version =${TELEMETRY_FORGE_AGENT_VERSION}"
}

@test "verify preset env vars have correct values" {
    # We run Fluent Bit with a dummy input that uses the env vars in the config to ensure they are set and have correct values.
    # This will also use a stdout output plugin to print out the dummy record which will contain the env vars in the output, allowing us to assert on their values.
    # Finally we include an exit plugin to ensure Fluent Bit exits after processing the dummy record or with a time delay, otherwise it would run indefinitely and the test would timeout.

    assert_file_exists "$BATS_TEST_DIRNAME/resources/environment-fluent-bit.yaml"
    # Dry run initially to verify the config is valid
    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/environment-fluent-bit.yaml" --dry-run
    assert_success
    refute_output --partial "[error]"

    # Now run it for real and check the output contains the env vars with correct values
    run "$FLUENT_BIT_BINARY" -c "$BATS_TEST_DIRNAME/resources/environment-fluent-bit.yaml"
    assert_success
    refute_output --partial "[error]"

    # The input string is '{"distro": "${AGENT_DISTRO}", "package_type": "${AGENT_PACKAGE_TYPE}", "version": "${AGENT_VERSION}", "os": "${OS_TYPE}"}'
    # distro will be set to a value like "ubuntu/latest" or "amazonlinux/2023"
    # package_type will be set to "PACKAGE" or "CONTAINER"
    # version will be set to the agent version like "0.1.0"
    # os will be set to the OS type like "linux" or "darwin"

    # We can assert on the output to check that the env vars are set and have correct values. We will check that distro, package_type, version and os are all present in the output with expected values.

    # distro should be set to a value like "ubuntu/latest" or "amazonlinux/2023" plus macos/windows variants so we can just check that it is set to some value and not empty
    assert_output --partial '"distro"=>"'

    if [ -z "${TELEMETRY_FORGE_AGENT_IMAGE:-}" ]; then
        # If TELEMETRY_FORGE_AGENT_IMAGE is not set, we are likely running a package build, so package_type should be "PACKAGE"
        assert_output --partial '"package_type"=>"PACKAGE"'
    else
        # If TELEMETRY_FORGE_AGENT_IMAGE is set, we are likely running a container build, so package_type should be "CONTAINER"
        assert_output --partial '"package_type"=>"CONTAINER"'
    fi

    if [[ "$(uname -s)" == "Darwin" ]]; then
        # If we are running on macOS, os should be set to "macos"
        assert_output --partial '"os"=>"macos"'
    elif [[ "$(uname -s)" == "Linux" ]]; then
        # If we are running on Linux, os should be set to "linux"
        assert_output --partial '"os"=>"linux"'
    else
        # Windows
        assert_output --partial '"os"=>"windows"'
    fi

    # Version should be passed in to verify directly
    assert_output --partial '"version"=>"'"${TELEMETRY_FORGE_AGENT_VERSION}"'"'
}
