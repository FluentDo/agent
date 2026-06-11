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

# Build metadata: all variables are mandatory for enterprise builds
if(NOT DEFINED TELEMETRY_FORGE_AGENT_DISTRO OR "${TELEMETRY_FORGE_AGENT_DISTRO}" STREQUAL "")
  message(FATAL_ERROR "TELEMETRY_FORGE_AGENT_DISTRO must be set for enterprise builds")
endif()

if(NOT DEFINED TELEMETRY_FORGE_AGENT_PACKAGE_TYPE OR "${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE}" STREQUAL "")
  message(FATAL_ERROR "TELEMETRY_FORGE_AGENT_PACKAGE_TYPE must be set for enterprise builds")
endif()

if(NOT DEFINED TELEMETRY_FORGE_AGENT_VERSION OR "${TELEMETRY_FORGE_AGENT_VERSION}" STREQUAL "")
  set(TELEMETRY_FORGE_AGENT_VERSION ${FLB_VERSION_STR})
  message(STATUS "TELEMETRY_FORGE_AGENT_VERSION not set, defaulting to FLB_VERSION_STR=${FLB_VERSION_STR}")
endif()

FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_DISTRO ${TELEMETRY_FORGE_AGENT_DISTRO})
message(STATUS "Build distro: ${TELEMETRY_FORGE_AGENT_DISTRO}")

FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_PACKAGE_TYPE ${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE})
message(STATUS "Build package type: ${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE}")

FLB_DEFINITION_VAL(TELEMETRY_FORGE_AGENT_VERSION ${TELEMETRY_FORGE_AGENT_VERSION})
message(STATUS "Build agent version: ${TELEMETRY_FORGE_AGENT_VERSION}")
