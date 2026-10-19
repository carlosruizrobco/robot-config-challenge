# Job image for the ubuntu-latest label of the local Gitea Actions runner.
# Pinned by digest so every build starts from the same image.
FROM python:3.12.15-slim-trixie@sha256:05cda9777409a9c3ffddd94a4c476b79f0769a0b4857f0c7ed9226b6800b0d6f

ARG NODE_VERSION=24.21.0
ARG GO_VERSION=1.27.2
ARG TARGETARCH

# The apt packages (git, and the helpers used to download Node.js and Go) are
# not pinned to exact versions. Debian removes superseded package versions
# from its mirrors at each point release, so an exact pin would eventually
# break this build. They come from Debian trixie (13), the base image's release.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      ca-certificates curl xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) node_arch=x64;   node_sha=fd8e59d5a511510f6a298afb548f18c7d2b1be404d8b4a27d94fbe49f56cb2d6; \
             go_sha=ecbadb99091a3f46e31f5f934b068b1864eafa7995211b39eaddf76996045fe5; go_arch=amd64 ;; \
      arm64) node_arch=arm64; node_sha=6ad1325edbdb5649c379b75a237147a666c95d4f9ae8d340fef2d1575d289ad2; \
             go_sha=94f3e30b8e374bc285e7dadc11e0865726b9bc6e85b841ccceaabc0214c6b7c8; go_arch=arm64 ;; \
      *) echo "unsupported architecture" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    echo "${node_sha}  /tmp/node.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --exclude='*/include' --exclude='*/share'; \
    curl -fsSLo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz"; \
    echo "${go_sha}  /tmp/go.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/go.tar.gz -C /usr/local; \
    rm /tmp/node.tar.xz /tmp/go.tar.gz

ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH
