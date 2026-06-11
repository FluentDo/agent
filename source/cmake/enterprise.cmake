message(STATUS "Running Enterprise build set up")
FLB_DEFINITION(FLB_ENTERPRISE)

# For legacy builds we need to handle this explicitly in case it is removed from the source
if(CMAKE_INSTALL_PREFIX MATCHES "/opt/td-agent-bit")
  set(FLB_TD ON)
endif()

# Ensure we have specific options enabled (they may get disabled implicitly due to missing dependencies)
function(validate_required_options)
    set(REQUIRED_OPTIONS ${ARGV})

    foreach(OPT ${REQUIRED_OPTIONS})
        if(NOT ${OPT})
            message(FATAL_ERROR "ERROR: ${OPT} is required but disabled.")
        endif()
    endforeach()

    message(STATUS "All required options validated successfully")
endfunction()

# Build metadata: distribution and package type
if(DEFINED TELEMETRY_FORGE_AGENT_DISTRO AND NOT "${TELEMETRY_FORGE_AGENT_DISTRO}" STREQUAL "")
  FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_DISTRO ${TELEMETRY_FORGE_AGENT_DISTRO})
  message(STATUS "Build distro: ${TELEMETRY_FORGE_AGENT_DISTRO}")
endif()

if(DEFINED TELEMETRY_FORGE_AGENT_PACKAGE_TYPE AND NOT "${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE}" STREQUAL "")
  FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_PACKAGE_TYPE ${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE})
  message(STATUS "Build package type: ${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE}")
endif()

# Build metadata: version set by the build or default to the FLB_VERSION_STR version defined in the root file
if(DEFINED TELEMETRY_FORGE_AGENT_VERSION AND NOT "${TELEMETRY_FORGE_AGENT_VERSION}" STREQUAL "")
  FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_VERSION ${FLB_VERSION_STR})
  message(STATUS "Build agent version: ${TELEMETRY_FORGE_AGENT_VERSION}")
endif()
