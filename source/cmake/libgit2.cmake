
# libgit2 (Git library) - REQUIRED for git_config plugin
option(LIBGIT2_USE_STATIC_LIBS "Use static libgit2 library with all dependencies" OFF)

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
  if(LIBGIT2_USE_STATIC_LIBS)
    message(STATUS "Using static libgit2 with all dependencies")
    execute_process(
      COMMAND ${PKG_CONFIG_EXECUTABLE} --libs --static libgit2
      OUTPUT_VARIABLE LIBGIT2_LDFLAGS
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    execute_process(
      COMMAND ${PKG_CONFIG_EXECUTABLE} --cflags libgit2
      OUTPUT_VARIABLE LIBGIT2_CFLAGS
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(LIBGIT2_LIBRARIES ${LIBGIT2_LDFLAGS})
    set(LIBGIT2_INCLUDE_DIRS ${LIBGIT2_CFLAGS})
    set(LIBGIT2_FOUND TRUE)
    separate_arguments(LIBGIT2_LIBRARIES)
    separate_arguments(LIBGIT2_INCLUDE_DIRS)
  else()
    pkg_check_modules(LIBGIT2 REQUIRED libgit2)
  endif()
  include_directories(${LIBGIT2_INCLUDE_DIRS})
  link_directories(${LIBGIT2_LIBRARY_DIRS})
endif()
set(LIBGIT2_FOUND TRUE)

# Optionally link libgit2 with static libssh2 if required on certain platforms when we build from source
# Note: When LIBGIT2_USE_STATIC_LIBS is enabled, pkg-config --static already includes libssh2
option( LIBSSH2_USE_STATIC_LIBS "Link libgit2 with static libssh2" OFF )
if( LIBSSH2_USE_STATIC_LIBS AND NOT LIBGIT2_USE_STATIC_LIBS )
  message(STATUS "Linking libgit2 with static libssh2")
  set( LIBSSH2_LIBRARY_PATH "/usr/local/lib/libssh2.a" CACHE PATH "Path to the static libssh2 library" )
  set(LIBGIT2_LIBRARIES ${LIBGIT2_LIBRARIES} ${LIBSSH2_LIBRARY_PATH})
endif()

if(LIBGIT2_FOUND)
  message(STATUS "libgit2 found: ${LIBGIT2_LIBRARIES}")
else()
  message(FATAL_ERROR "libgit2 is required but not found. Please install libgit2.")
endif()

