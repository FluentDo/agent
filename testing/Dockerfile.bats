ARG BASE_BUILDER=docker.io/dokken/centos-7

FROM bats/bats:1.12.0 AS bats

ARG BASE_BUILDER
FROM ${BASE_BUILDER} AS test

COPY --from=bats /opt/bats /opt/bats
RUN /opt/bats/install.sh /usr/local

# Install git for testing the git config plugin
RUN if ! command -v git &>/dev/null; then \
        if command -v yum &>/dev/null; then \
            yum install -y git; \
        elif command -v microdnf &>/dev/null; then \
            microdnf install -y git; \
        elif command -v dnf &>/dev/null; then \
            dnf install -y git; \
        elif command -v apk &>/dev/null; then \
            apk add --no-cache git; \
        elif command -v zypper &>/dev/null; then \
            zypper install -y git; \
        elif command -v apt-get &>/dev/null; then \
            apt-get update && apt-get install -y git; \
        else \
            echo "ERROR: unable to install git"; \
            exit 1; \
        fi \
    fi

COPY testing/ /testing/

# Put packages to install here
VOLUME [ "/downloads" ]
ENV DOWNLOADS_DIR=/downloads

WORKDIR /testing
ENTRYPOINT [ "/testing/bats-entrypoint.sh" ]
CMD [ "--filter-tags", "functional", "--recursive", "/testing/bats/tests" ]
