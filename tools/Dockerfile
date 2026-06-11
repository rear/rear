ARG IMAGE
FROM $IMAGE
LABEL description="$IMAGE patched to build and run ReaR"
SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]
COPY run-in-docker-build.sh /run-in-docker-build.sh
RUN /run-in-docker-build.sh
