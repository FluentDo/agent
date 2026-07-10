# Set this to the base image to use in each case, so if we want to build for amazonlinux/2.arm64v8
# we would set BASE_BUILDER=amazonlinux-2.arm64v8-base.
ARG BASE_BUILDER=amazonlinux-2-base
# Lookup the name to use below but should follow the '<distro>-base' convention with slashes replaced.
# Use buildkit to skip unused base images: DOCKER_BUILDKIT=1

# Used to differentiate in CI from main/PR builds
ARG CACHE_ID=main

# Multiarch support
FROM multiarch/qemu-user-static:x86_64-aarch64 AS multiarch-aarch64

# amazonlinux/2 base image
FROM amazonlinux:2 AS amazonlinux-2-base

ENV CMAKE_HOME="/opt/cmake"
ARG CMAKE_VERSION="3.31.6"
ARG CMAKE_URL="https://github.com/Kitware/CMake/releases/download"

ARG CACHE_ID
# hadolint ignore=DL3033,DL3032
RUN --mount=type=cache,target=/var/cache/yum,sharing=locked,id=amazonlinux-2-${CACHE_ID} yum -y update && \
    yum install -y rpm-build curl ca-certificates make bash \
    gcc gcc-c++ \
    wget unzip systemd-devel wget flex bison \
    cyrus-sasl-lib cyrus-sasl-devel openssl openssl-libs openssl-devel \
    glibc-devel \
    libyaml-devel zlib-devel libcurl-devel pkgconf-pkg-config \
    tar gzip perl-core
# Split into separate layer to allow us to cache above
RUN yum clean all

# hadolint ignore=DL4006
RUN mkdir -p "${CMAKE_HOME}" && \
    cmake_download_url="${CMAKE_URL}/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz" && \
    echo "Downloading CMake ${CMAKE_VERSION}: ${cmake_download_url} -> ${CMAKE_HOME}" && \
    curl -jksSL "${cmake_download_url}" | tar -xzf - -C "${CMAKE_HOME}" --strip-components 1

ENV PATH="${CMAKE_HOME}/bin:${PATH}"

# amazonlinux/2.arm64v8 base image
FROM arm64v8/amazonlinux:2 AS amazonlinux-2.arm64v8-base

COPY --from=multiarch-aarch64 /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

ENV CMAKE_HOME="/opt/cmake"
ARG CMAKE_VERSION="3.31.6"
ARG CMAKE_URL="https://github.com/Kitware/CMake/releases/download"

ARG CACHE_ID
# hadolint ignore=DL3033,DL3032
RUN --mount=type=cache,target=/var/cache/yum,sharing=locked,id=amazonlinux-2-arm64-${CACHE_ID} yum -y update && \
    yum install -y rpm-build curl ca-certificates gcc gcc-c++ make bash \
    wget unzip systemd-devel wget flex bison \
    cyrus-sasl-lib cyrus-sasl-devel openssl openssl-libs openssl-devel \
    libyaml-devel zlib-devel libcurl-devel pkgconf-pkg-config \
    tar gzip perl-core
# Split into separate layer to allow us to cache above
RUN yum clean all

# hadolint ignore=DL4006
RUN mkdir -p "${CMAKE_HOME}" && \
    cmake_download_url="${CMAKE_URL}/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$(uname -m).tar.gz" && \
    echo "Downloading CMake ${CMAKE_VERSION}: ${cmake_download_url} -> ${CMAKE_HOME}" && \
    curl -jksSL "${cmake_download_url}" | tar -xzf - -C "${CMAKE_HOME}" --strip-components 1

ENV PATH="${CMAKE_HOME}/bin:${PATH}"

# hadolint ignore=DL3006
FROM $BASE_BUILDER AS base-builder

ARG TELEMETRY_FORGE_AGENT_DISTRO
ENV TELEMETRY_FORGE_AGENT_DISTRO=$TELEMETRY_FORGE_AGENT_DISTRO
ARG TELEMETRY_FORGE_AGENT_PACKAGE_TYPE
ENV TELEMETRY_FORGE_AGENT_PACKAGE_TYPE=$TELEMETRY_FORGE_AGENT_PACKAGE_TYPE

ARG FLB_NIGHTLY_BUILD
ENV FLB_NIGHTLY_BUILD=$FLB_NIGHTLY_BUILD

# We need a more recent OpenSSL as well so build from source
ADD https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz /openssl/
RUN tar -xzvf /openssl/openssl-3.5.2.tar.gz -C /openssl
WORKDIR /openssl/openssl-3.5.2
RUN ./Configure && make -j "$(getconf _NPROCESSORS_ONLN)" && make install

# Build libssh2 from source as static library with -fPIC (required for libgit2)
ARG LIBSSH2_VER=1.11.1
WORKDIR /tmp
RUN curl -LO https://www.libssh2.org/download/libssh2-${LIBSSH2_VER}.tar.gz && \
    tar xf libssh2-${LIBSSH2_VER}.tar.gz
WORKDIR /tmp/libssh2-${LIBSSH2_VER}
RUN CFLAGS="-fPIC" \
    LDFLAGS="-L/openssl/openssl-3.5.2 -L/usr/local/lib64" \
    CPPFLAGS="-I/openssl/openssl-3.5.2/include" \
    ./configure --prefix=/usr/local --enable-static --disable-shared --disable-examples-build \
        --with-openssl --with-libssl-prefix=/openssl/openssl-3.5.2 && \
    make -j "$(getconf _NPROCESSORS_ONLN)" && \
    make install
    
# Build libgit2 from source (required for git_config plugin)
ARG LIBGIT2_VER=1.9.1
WORKDIR /tmp
RUN curl -LO https://github.com/libgit2/libgit2/archive/refs/tags/v${LIBGIT2_VER}.tar.gz && \
    tar xf v${LIBGIT2_VER}.tar.gz
WORKDIR /tmp/libgit2-${LIBGIT2_VER}
RUN cmake -B build -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DLINK_WITH_STATIC_LIBRARIES=ON \
        -DUSE_SSH=ON \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        -DOPENSSL_ROOT_DIR=/openssl/openssl-3.5.2 && \
    cmake --build build --target install -- -j "$(getconf _NPROCESSORS_ONLN)" && \
    echo "/usr/local/lib64" > /etc/ld.so.conf.d/libgit2.conf && \
    ldconfig

# Docker context must be the 'source' directory of the repo
WORKDIR /tmp/fluent-bit/
COPY . ./

WORKDIR /tmp/fluent-bit/build/
FROM base-builder AS builder

# CMake configuration variables
ARG CMAKE_INSTALL_PREFIX=/opt/telemetryforge-agent/
ARG CMAKE_INSTALL_SYSCONFDIR=/etc/

RUN PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH" \
    cmake -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX" \
        -DCMAKE_RULE_MESSAGES:BOOL=OFF -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_SYSCONFDIR="$CMAKE_INSTALL_SYSCONFDIR" \
        -DFLB_NIGHTLY_BUILD="$FLB_NIGHTLY_BUILD" \
        -DFLB_JEMALLOC_OPTIONS="$FLB_JEMALLOC_OPTIONS" \
        -DTELEMETRY_FORGE_AGENT_DISTRO="${TELEMETRY_FORGE_AGENT_DISTRO}" \
        -DTELEMETRY_FORGE_AGENT_PACKAGE_TYPE="${TELEMETRY_FORGE_AGENT_PACKAGE_TYPE}" \
        -DOPENSSL_ROOT_DIR=/openssl/openssl-3.5.2 \
        -DOPENSSL_USE_STATIC_LIBS=On \
        -DLIBSSH2_USE_STATIC_LIBS=On \
        -DLIBSSH2_LIBRARY_PATH=/usr/local/lib/libssh2.a \
        ../

VOLUME [ "/output" ]
CMD [ "/bin/bash", "-c", "make -j 4 && cpack -G RPM && cp *.rpm /output/" ]
