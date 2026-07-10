# libgit2 (Git library) - REQUIRED for git_config plugin
include(CheckCSourceCompiles)

set(FLB_LIBGIT2_MIN_VERSION "0.27.0")

# Check for minimum required version of libgit2 required by the plugin. 
function(flb_assert_libgit2_min_version)
  set(CMAKE_REQUIRED_INCLUDES ${LIBGIT2_INCLUDE_DIRS})
  check_c_source_compiles("\
#include <git2/version.h>\n\
#if defined(LIBGIT2_VERSION_CHECK)\n\
#  if !LIBGIT2_VERSION_CHECK(0, 27, 0)\n\
#    error libgit2 version is too old\n\
#  endif\n\
#elif defined(LIBGIT2_VERSION_MAJOR) && defined(LIBGIT2_VERSION_MINOR) && defined(LIBGIT2_VERSION_REVISION)\n\
#  if (LIBGIT2_VERSION_MAJOR == 0 && LIBGIT2_VERSION_MINOR < 27)\n\
#    error libgit2 version is too old\n\
#  endif\n\
#elif defined(LIBGIT2_VER_MAJOR) && defined(LIBGIT2_VER_MINOR) && defined(LIBGIT2_VER_REVISION)\n\
#  if (LIBGIT2_VER_MAJOR == 0 && LIBGIT2_VER_MINOR < 27)\n\
#    error libgit2 version is too old\n\
#  endif\n\
#else\n\
#  error unable to determine libgit2 version\n\
#endif\n\
int main(void) { return 0; }\n" LIBGIT2_VERSION_OK)
  unset(CMAKE_REQUIRED_INCLUDES)

  if(NOT LIBGIT2_VERSION_OK)
    message(FATAL_ERROR "libgit2 >= ${FLB_LIBGIT2_MIN_VERSION} is required for git_config support.")
  endif()
endfunction()

if(FLB_SYSTEM_WINDOWS)
  # On Windows, use paths provided via CMake flags from Dockerfile
  if(NOT LIBGIT2_INCLUDE_DIR OR NOT LIBGIT2_LIBRARY)
    message(FATAL_ERROR "libgit2 is required but not found. Please install libgit2 and set LIBGIT2_INCLUDE_DIR and LIBGIT2_LIBRARY.")
  endif()
  set(LIBGIT2_FOUND TRUE)
  set(LIBGIT2_INCLUDE_DIRS ${LIBGIT2_INCLUDE_DIR})
  set(LIBGIT2_LIBRARIES ${LIBGIT2_LIBRARY})
  include_directories(${LIBGIT2_INCLUDE_DIRS})
else()
  # On Unix-like systems, use pkg-config
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(LIBGIT2 REQUIRED libgit2>=${FLB_LIBGIT2_MIN_VERSION})
  include_directories(${LIBGIT2_INCLUDE_DIRS})
  link_directories(${LIBGIT2_LIBRARY_DIRS})
endif()
set(LIBGIT2_FOUND TRUE)

flb_assert_libgit2_min_version()

# Optionally link libgit2 with static libssh2 if required on certain platforms when we build from source
option( LIBSSH2_USE_STATIC_LIBS "Link libgit2 with static libssh2" OFF )
if( LIBSSH2_USE_STATIC_LIBS )
  message(STATUS "Linking libgit2 with static libssh2")
  set( LIBSSH2_LIBRARY_PATH "/usr/local/lib/libssh2.a" CACHE PATH "Path to the static libssh2 library" )
  set(LIBGIT2_LIBRARIES ${LIBGIT2_LIBRARIES} ${LIBSSH2_LIBRARY_PATH})
endif()

if(LIBGIT2_FOUND)
  message(STATUS "libgit2 found: ${LIBGIT2_LIBRARIES}")
else()
  message(FATAL_ERROR "libgit2 is required but not found. Please install libgit2.")
endif()

