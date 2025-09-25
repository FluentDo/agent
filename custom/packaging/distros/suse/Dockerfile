# Special Dockerfile to build all targets, the only difference is
# the packages in the base image.
# Set this to the base image to use in each case, so if we want to build for suse/15
# we would set BASE_BUILDER=suse-15-base.
ARG BASE_BUILDER
# Lookup the name to use below but should follow the '<distro>-base' convention with slashes replaced.
# Use buildkit to skip unused base images: DOCKER_BUILDKIT=1

# We need cmake >3.12 as well for some dependencies.
# Unfortunately for some targets this is not available as a dependency so we install the binary direct
# from the cmake download site. This is the version used.
ARG CMAKE_VERSION=3.23.1

# Multiarch support
FROM multiarch/qemu-user-static:x86_64-aarch64 as multiarch-aarch64

# suse/12 base image
# Based on Google ops agent to use OpenSUSE Leap 42.3 to emulate SLES 12:
# https://en.opensuse.org/openSUSE:Build_Service_cross_distribution_howto#Detect_a_distribution_flavor_for_special_code
FROM opensuse/archive:42.3 AS suse-12-base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# zypper/libcurl has a use-after-free bug that causes segfaults for particular download sequences.
# If this bug happens to trigger in the future, adding a "zypper -n download" of a subset of the packages can avoid the segfault.
# hadolint ignore=DL3036,DL3037
RUN set -x; \
    # The 'OSS Update' repo signature is no longer valid, so verify the checksum instead.
    zypper --no-gpg-check refresh 'OSS Update' && \
    (echo 'b889b4bba03074cd66ef9c0184768f4816d4ccb1fa9ec2721c5583304c5f23d0  /var/cache/zypp/raw/OSS Update/repodata/repomd.xml' | sha256sum --check) && \
    zypper -n install curl tar git systemd autoconf automake flex libtool libcurl-devel libopenssl-devel libyajl-devel \
    gcc gcc-c++ zlib-devel rpm-build expect systemd-devel systemd-rpm-macros && \
    # Remove expired root certificate.
    mv /var/lib/ca-certificates/pem/DST_Root_CA_X3.pem /etc/pki/trust/blacklist/ && \
    update-ca-certificates && \
    # Allow fluent-bit to find systemd
    ln -fs /usr/lib/systemd /lib/systemd

# suse/15 base image
FROM opensuse/leap:15.3 AS suse-15-base

# hadolint ignore=DL3036,DL3037
RUN set -x; \
    zypper -n install curl tar git systemd autoconf automake flex libtool libcurl-devel libopenssl-devel libyajl-devel \
    gcc gcc-c++ zlib-devel rpm-build expect systemd-devel systemd-rpm-macros && \
    # Allow fluent-bit to find systemd
    ln -fs /usr/lib/systemd /lib/systemd

# suse/15.arm64v8 base image
# hadolint ignore=DL3029
FROM --platform=arm64 opensuse/leap:15.3 AS suse-15.arm64v8-base
COPY --from=multiarch-aarch64 /usr/bin/qemu-aarch64-static /usr/bin/qemu-aarch64-static

# hadolint ignore=DL3036,DL3037
RUN set -x; \
    zypper -n install curl tar git systemd autoconf automake flex libtool libcurl-devel libopenssl-devel libyajl-devel \
    gcc gcc-c++ zlib-devel rpm-build expect systemd-devel systemd-rpm-macros && \
    # Allow fluent-bit to find systemd
    ln -fs /usr/lib/systemd /lib/systemd

# Common build for all distributions now
# hadolint ignore=DL3006
FROM $BASE_BUILDER as builder

ARG CMAKE_VERSION
RUN CMAKE_ARCH=$(uname -m); \
    curl --output /tmp/cmake.sh -L "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-$CMAKE_ARCH.sh" && \
    mkdir -p /opt/cmake && \
    /bin/sh /tmp/cmake.sh --skip-license --prefix=/opt/cmake --include_subdir && \
    ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake && \
    ln -sf /opt/cmake/bin/cpack /usr/local/bin/cpack

# Bison needs to be built from source unfortunately as at least one target does not provide it so we want to be common for all
ARG BISON_VER=3.7.2
ARG BISON_URL=http://ftp.gnu.org/gnu/bison
ARG FLEX_VER=2.6.4
ARG FLEX_URL=https://github.com/westes/flex/files/981163
ADD ${BISON_URL}/bison-${BISON_VER}.tar.gz /bison/
ADD ${FLEX_URL}/flex-${FLEX_VER}.tar.gz /flex/
RUN tar -xzvf /bison/bison-${BISON_VER}.tar.gz -C /bison/ && tar -xzvf /flex/flex-${FLEX_VER}.tar.gz -C /flex/

# Flex needs Bison so do first
WORKDIR /bison/bison-${BISON_VER}/
RUN ./configure && make -j "$(getconf _NPROCESSORS_ONLN)" && make install
WORKDIR /flex/flex-${FLEX_VER}/
RUN ./configure && make -j "$(getconf _NPROCESSORS_ONLN)" && make install

ARG FLB_NIGHTLY_BUILD
ENV FLB_NIGHTLY_BUILD=$FLB_NIGHTLY_BUILD

# Docker context must be the base of the repo
WORKDIR /source/fluent-bit/
COPY . ./

WORKDIR /source/fluent-bit/build/
# CMake configuration variables
# Unused
ARG CFLAGS
ARG CMAKE_INSTALL_PREFIX=/opt/fluent-bit/
ARG CMAKE_INSTALL_SYSCONFDIR=/etc/
ARG FLB_RELEASE=On

# No YAML support
ARG FLB_CONFIG_YAML=Off
# Triggers errors on librdkafka if enabled
ARG WITH_CURL=Off

RUN cmake -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX" \
    -DCMAKE_RULE_MESSAGES:BOOL=OFF -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_SYSCONFDIR="$CMAKE_INSTALL_SYSCONFDIR" \
    -DFLB_RELEASE="$FLB_RELEASE" \
    -DFLB_NIGHTLY_BUILD="$FLB_NIGHTLY_BUILD" \
    -DFLB_CONFIG_YAML="${FLB_CONFIG_YAML}" \
    -DWITH_CURL="${WITH_CURL}" \
    ../

VOLUME [ "/output" ]
CMD [ "/bin/bash", "-c", "make --no-print-directory -j 4 && cpack -G RPM && cp *.rpm /output/" ]
