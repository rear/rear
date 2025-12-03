ARG CONTAINER_REPO=263262308774.dkr.ecr.eu-west-1.amazonaws.com

FROM ${CONTAINER_REPO}/ns/mirror/prd/library/debian:12.11-slim

RUN apt-get update && \
    apt-get install -y \
    git \
    bats \
    bash \
    coreutils \
    curl \
    make \
    && rm -rf /var/lib/apt/lists/*

ARG user=build
ARG group=build
ARG uid=1000
ARG gid=1000

RUN groupadd -g "${gid}" "${group}"                                           \
    && useradd -l -c "Build user" -d "/${user}" -u "${uid}" -g "${gid}"       \
        -s /bin/bash -m "${user}"

USER build
